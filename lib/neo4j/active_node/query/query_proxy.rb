module Neo4j
  module ActiveNode
    module Query

      class QueryProxy
        include Enumerable

        def initialize(model, association = nil, options = {})
          @model = model
          @association = association
          @options = options
          @chain = []
        end

        def each
          query.pluck(:result).each do |obj|
            yield obj
          end
        end

        METHODS = %w[where order skip limit]

        METHODS.each do |method|
          module_eval(%Q{
            def #{method}(*args)
              build_deeper_query_proxy(:#{method}, args)
            end}, __FILE__, __LINE__)
        end

        alias_method :offset, :skip
        alias_method :order_by, :order

        # For getting variables which have been defined as part of the association chain
        def pluck(*args)
          self.query.pluck(*args)
        end

        # Like calling #query_as, but for when you don't care about the variable name
        def query
          query_as(self._var || :result)
        end

        def as(var)
          @options[:var] = var
        end

        # Build a Neo4j::Core::Query object for the QueryProxy
        def query_as(var)
          query = if @association
            chain_var = _association_chain_var
            var = self._var if self._var
            label_string = @model && ":`#{@model.name}`"
            (_association_query_start(chain_var) & _query_model_as(var)).match("#{chain_var}#{_association_arrow}(#{var}#{label_string})")
          else
            _query_model_as(var)
          end

          @chain.inject(query) do |query, (method, arg)|
            if arg.respond_to?(:call)
              query.send(method, arg.call(var))
            else
              query.send(method, arg)
            end
          end
        end

        # Cypher string for the QueryProxy's query
        def to_cypher
          query.to_cypher
        end

        # To add a relationship for the node for the association on this QueryProxy
        def <<(other_node)
          if @association
            raise ArgumentError, "Node must be of the association's class when model is specified" if @model && other_node.class != @model

            _association_query_start(:start)
              .match(end: other_node.class)
              .where(end: {neo_id: other_node.neo_id})
              .create("start#{_association_arrow}end").exec
          else
            raise "Can only create associations on associations"
          end
        end

        def method_missing(method_name, *args)
          if @model && @model.respond_to?(method_name)
            @model.query_proxy = self
            result = @model.send(method_name, *args)
            @model.query_proxy = nil
            result
          else
            super
          end
        end

        protected
        # Methods are underscored to prevent conflict with user class methods

        def _add_links(links)
          @chain += links
        end

        def _query_model_as(var)
          if @model
            label = @model.respond_to?(:mapped_label_name) ? @model.mapped_label_name : @model
            neo4j_session.query.match(var => label)
          else
            neo4j_session.query.match(var)
          end
        end

        def _association_arrow
          @association && @association.arrow_cypher
        end

        def _chain_level
          if @options[:start_object]
            1
          elsif query_proxy = @options[:query_proxy]
            query_proxy._chain_level + 1
          else
            raise "Crazy error" # TODO: Better error
          end
        end

        def _var
          @options[:var]
        end

        def _association_chain_var
          if start_object = @options[:start_object]
            :"#{start_object.class.name.downcase}#{start_object.neo_id}"
          elsif query_proxy = @options[:query_proxy]
            query_proxy._var || :"node#{_chain_level}"
          else
            raise "Crazy error" # TODO: Better error
          end
        end

        def _association_query_start(var)
          if start_object = @options[:start_object]
            start_object.query_as(var)
          elsif query_proxy = @options[:query_proxy]
            query_proxy.query_as(var)
          else
            raise "Crazy error" # TODO: Better error
          end
        end

        private

        def build_deeper_query_proxy(method, args)
          self.dup.tap do |new_query|
          args.each do |arg|
            new_query._add_links(links_for_arg(method, arg))
          end
        end
      end

      def links_for_arg(method, arg)
        method_to_call = "links_for_#{method}_arg"

        default = [[method, arg]]

        self.send(method_to_call, arg) || default
      rescue NoMethodError
        default
      end

      def links_for_where_arg(arg)
        node_num = 1
        result = []
        if arg.is_a?(Hash)
          arg.map do |key, value|
            if @model.has_one_relationship?(key)
              neo_id = value.try(:neo_id) || value
              raise ArgumentError, "Invalid value for '#{key}' condition" if not neo_id.is_a?(Integer)

              n_string = "n#{node_num}"
              dir = @model.relationship_dir(key)

              arrow = dir == :outgoing ? '-->' : '<--'
              result << [:match, ->(v) { "#{v}#{arrow}(#{n_string})" }]
              result << [:where, ->(v) { {"ID(#{n_string})" => neo_id.to_i} }]
              node_num += 1
            else
              result << [:where, ->(v) { {v => {key => value}}}]
            end
          end
        end
        result
      end

      def links_for_order_arg(arg)
        [[:order, ->(v) { {v => arg} }]]
      end


      end

    end
  end
end


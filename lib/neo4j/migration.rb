module Neo4j
  class Migration
    class AddIdProperty < Neo4j::Migration
      attr_reader :models_filename

      def initialize
        @models_filename = File.join(Rails.root.join('db', 'neo4j-migrate'), 'add_id_property.yml')
      end

      def migrate
        models = ActiveSupport::HashWithIndifferentAccess.new(YAML.load_file(models_filename))[:models]
        puts "This task will add an ID Property every node in the given file."
        puts "It may take a significant amount of time, please be patient."
        models.each do |model|
          puts
          puts
          puts "Adding IDs to #{model}"
          add_ids_to model.constantize
        end
      end

      def setup
        FileUtils.mkdir_p("db/neo4j-migrate")
        unless File.file?(models_filename)
          File.open(models_filename, 'w') do |file|
            file.write("# Provide models to which IDs should be added.\n# It will only modify nodes that do not have IDs. There is no danger of overwriting data.\n# models: [Student,Lesson,Teacher,Exam]\nmodels: []")
          end
        end
      end

      private

      def add_ids_to(model)
        require 'benchmark'

        max_per_batch = (ENV['MAX_PER_BATCH'] || default_max_per_batch).to_i

        label = model.mapped_label_name
        property = model.primary_key
        nodes_left = 1
        last_time_taken = nil

        until nodes_left == 0
          nodes_left = Neo4j::Session.query.match(n: label).where("NOT has(n.#{property})").return("COUNT(n) AS ids").first.ids

          time_per_node = last_time_taken / max_per_batch if last_time_taken
          print "Running first batch...\r"
          if time_per_node
            eta_seconds = (nodes_left * time_per_node).round
            print "#{nodes_left} nodes left.  Last batch: #{(time_per_node * 1000.0).round(1)}ms / node (ETA: #{eta_seconds / 60} minutes)\r"
          end

          return if nodes_left == 0
          to_set = [nodes_left, max_per_batch].min

          new_ids = to_set.times.map { new_id_for(model) }
          begin
            last_time_taken = id_batch_set(label, property, new_ids, to_set)
          rescue Neo4j::Server::CypherResponse::ResponseError, Faraday::TimeoutError
            new_max_per_batch = (max_per_batch * 0.8).round
            puts "Error querying #{max_per_batch} nodes.  Trying #{new_max_per_batch}"
            max_per_batch = new_max_per_batch
          end
        end
      end

      def id_batch_set(label, property, new_ids, to_set)
        Benchmark.realtime do
          Neo4j::Transaction.run do
            Neo4j::Session.query("MATCH (n:`#{label}`) WHERE NOT has(n.#{property})
              with COLLECT(n) as nodes, #{new_ids} as ids
              FOREACH(i in range(0,#{to_set - 1})|
                FOREACH(node in [nodes[i]]|
                  SET node.#{property} = ids[i]))
              RETURN distinct(true)
              LIMIT #{to_set}")
          end
        end
      end

      def default_max_per_batch
        900
      end

      def new_id_for(model)
        if model.id_property_info[:type][:auto]
          SecureRandom::uuid
        else
          model.new.send(model.id_property_info[:type][:on])
        end
      end
    end

    class AddClassnames < Neo4j::Migration
      attr_reader :classnames_filename, :classnames_filepath

      def initialize
        @classnames_filename = 'add_classnames.yml'
        @classnames_filepath = File.join(Rails.root.join('db', 'neo4j-migrate'), classnames_filename)
      end

      def migrate
        puts "Adding classnames. This make take some time."
        execute(true)
      end

      def test
        puts "TESTING! No queries will be executed."
        execute(false)
      end

      def setup
        puts "Creating file #{classnames_filepath}. Please use this as the migration guide."
        FileUtils.mkdir_p("db/neo4j-migrate")
        unless File.file?(@classnames_filepath)
          source = File.join(File.dirname(__FILE__), "..", "..", "config", "neo4j", classnames_filename)
          FileUtils.copy_file(source, classnames_filepath)
        end
      end

      private

      def execute(migrate = false)
        file_init
        map = []
        map.push :nodes         if @model_map[:nodes]
        map.push :relationships if @model_map[:relationships]
        map.each do |type|
          @model_map[type].each do |action, labels|
            do_classnames(action, labels, type, migrate)
          end
        end
      end

      def do_classnames(action, labels, type, migrate = false)
        method = type == :nodes ? :node_cypher : :rel_cypher
        labels.each do |label|
          puts cypher = self.send(method, label, action)
          execute_cypher(cypher) if migrate
        end
      end

      def file_init
        @model_map = ActiveSupport::HashWithIndifferentAccess.new(YAML.load_file(classnames_filepath)) 
      end

      def node_cypher(label, action)
        where, phrase_start = action_variables(action, 'n')
        puts "#{phrase_start} _classname '#{label}' on nodes with matching label:"
        "MATCH (n:`#{label}`) #{where} SET n._classname = '#{label}' RETURN COUNT(n) as modified"
      end

      def rel_cypher(hash, action)
        label = hash[0]
        value = hash[1]
        from = value[:from]
        raise "All relationships require a 'type'" unless value[:type]

        from_cypher = from ? "(from:`#{from}`)" : "(from)"
        to = value[:to]
        to_cypher = to ? "(to:`#{to}`)" : "(to)"
        type = "[r:`#{value[:type]}`]"
        where, phrase_start = action_variables(action, 'r')
        puts "#{phrase_start} _classname '#{label}' where type is '#{value[:type]}' using cypher:"
        "MATCH #{from_cypher}-#{type}->#{to_cypher} #{where} SET r._classname = '#{label}' return COUNT(r) as modified"
      end

      def execute_cypher(query_string)
        puts "Modified #{Neo4j::Session.query(query_string).first.modified} records"
        puts ""
      end

      def action_variables(action, identifier)
        case action
        when 'overwrite'
          ['', 'Overwriting']
        when 'add'
          ["WHERE NOT HAS(#{identifier}._classname)", 'Adding']
        else
          raise "Invalid action #{action} specified"
        end
      end
    end
  end
end

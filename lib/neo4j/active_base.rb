module Neo4j
  # To contain any base login for ActiveNode/ActiveRel which
  # is external to the main classes
  module ActiveBase
    class << self
      # private?
      def current_session
        (@current_driver ||= establish_session).tap do |session|
          fail 'No session defined!' if session.nil?
        end
      end

      def on_establish_session(&block)
        @establish_session_block = block
      end

      def establish_session
        make_session_wrap!(@establish_session_block.call) if @establish_session_block
      end

      def new_driver(url, options = {})
        verbose_query_logs = Neo4j::Config.fetch(:verbose_query_logs, false)
        Neo4j::Core::CypherSession::Driver
          .new(url, options.merge(wrap_level: :proc, verbose_query_logs: verbose_query_logs))
      end

      def current_transaction_or_session
        current_transaction || current_session
      end

      def query(*args)
        current_transaction_or_session.query(*args)
      end

      # Should support setting session via config options
      def current_session=(driver)
        @current_driver = make_session_wrap!(driver)
      end

      alias current_driver= current_session=

      def run_transaction(run_in_tx = true)
        Neo4j::Transaction.run(current_session, run_in_tx) do |tx|
          yield tx
        end
      end

      def new_transaction
        validate_model_schema!
        Neo4j::Transaction.new(current_session)
      end

      def new_query(options = {})
        validate_model_schema!
        Neo4j::Core::Query.new({session: current_session}.merge(options))
      end

      def magic_query(*args)
        if args.empty? || args.map(&:class) == [Hash]
          ActiveBase.new_query(*args)
        else
          ActiveBase.current_session.query(*args)
        end
      end

      def current_transaction
        validate_model_schema!
        Neo4j::Transaction.root
      end

      def label_object(label_name)
        Neo4j::Core::Label.new(label_name, current_session)
      end

      def logger
        @logger ||= (Neo4j::Config[:logger] || ActiveSupport::Logger.new(STDOUT))
      end

      private

      def validate_model_schema!
        Neo4j::ModelSchema.validate_model_schema! unless Neo4j::Migrations.currently_running_migrations
      end

      def make_session_wrap!(driver)
        driver.instance_variable_get('@options')[:wrap_level] = :proc
        driver
      end
    end
  end
end

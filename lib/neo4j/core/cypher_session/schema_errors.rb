module Neo4j
  module Core
    module CypherSession
      module SchemaErrors
        class ConstraintValidationFailedError < CypherError; end
        class ConstraintAlreadyExistsError < CypherError; end
        class IndexAlreadyExistsError < CypherError; end
      end
    end
  end
end

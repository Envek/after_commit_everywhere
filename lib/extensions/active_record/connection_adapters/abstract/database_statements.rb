if Gem.loaded_specs["activerecord"].version < Gem::Version.create('4.2')
  module ActiveRecord
    module ConnectionAdapters
      module DatabaseStatements
        def transaction_open?
          open_transactions > 0
        end
      end
    end
  end
end

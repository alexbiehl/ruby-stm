module STM

  class TVar

    def initialize(value)
      @value = value
      @version = 0
      @lock = Mutex.new
      @suspended = ConditionVariable.new
    end

    # Locks the tvar for any safe access
    def unsafe_lock
      @lock.lock
    end

    # Unlocks the tvar for any safe access
    def unsafe_unlock
      @lock.unlock
    end

    # Unsafely reads the version, make sure you hold the lock!
    def unsafe_version
      @version
    end

    # Safely read the tvar.
    def unsafe_read
        return @version, @value
    end

    # Unsafely write the tvar, make sure you hold the lock!
    def unsafe_write(value)
      @version = @version + 1
      @value = value
    end

    # Safely read the tvar.
    def read
      @lock.synchronize {
        unsafe_read()
      }
    end


    def suspendOn

    end

  end

  class Txn

    class RetryError
    end

    class RollbackError
    end

    def initialize
      @read_set = {}
      @write_set = {}
    end

    def read(tvar)
      if @write_set.has_key? tvar
        # We have written this tvar in this transaction. Take the new value.
        @write_set[tvar]
      else
        # We haven't written it yet in this transaction, take value and version
        version, value = tvar.unsafe_read

        if @read_set.has_key? tvar
          # We have read the version/value in this transaction.
          if @read_set[tvar] != version
            # If the version don't match up retry again.
            raise RetryError
          end
        else
          # First time we have written this tvar, remember version
          @read_set[tvar] = version
        end
        value
      end
    end

    def write(tvar, value)
      @write_set[tvar] = value
    end

    def self.atomically(&blk)
      Txn.new.atomically(&blk)
    end

    def atomically(&blk)
      begin
        # Execute the transaction
        result = yield self

        # Collect and lock each tvar participating in this transaction
        tvars = (@read_set.keys + @write_set.keys).uniq
        tvars.each { |tvar| tvar.unsafe_lock }

        if is_valid? @read_set
          # We have a valid transaction and all the locks on the tvars, write the
          # new values from @write_set to them.
          @write_set.each { |tvar, new_value|
            tvar.unsafe_write(new_value)
          }

          # unlock tvars again
          tvars.each { |tvar| tvar.unsafe_unlock }
        else
          # umlock tvars again, this is duplicate code since
          # we are not sure we will reach the rest of the method.
          tvars.each { |tvar| tvar.unsafe_unlock }

          # Try again!
          raise RollbackError
        end

        return result

      rescue RollbackError
        # Some TVars changed dureing transaction, try again.
        atomically(blk)
      rescue RetryError

        read_set = @read_set
        write_set = @write_set

        read_set.each { |tvar, _| tvar.unsafe_lock }

        if is_valid? read_set

        else
          # Invalid transaction, rollback.
          read_set.each { |tvar, _| tvar.unsafe_unlock }
          atomically(blk)
        end

      end
    end

    # Checks for validit of this transaction
    def is_valid?(tvars)
      # Delete any tvar from read set which has the same version as when last read
      # if that collection is empty we have a valid transaction.
      tvars.reject { |tvar, version|
        tvar.unsafe_version == version
      }.empty?
    end

  end

end

var1 = STM::TVar.new(1)
var2 = STM::TVar.new(2)

result = STM::Txn.atomically { |txn|
  v1 = txn.read(var1)
  txn.write(var2, v1 + 5)
  txn.read(var2)
}

puts result

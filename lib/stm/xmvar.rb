require "stm/mvar"

module STM

  class XMVar

    UNIT = "UNIT"

    def initialize
      @value = MVar.new value
      @lock  = MVar.new UNIT
    end

    def read
      @value.read
    end

    def synchronizeWrites(&blk)
      @lock.take
      blk @value.read
      @lock.put UNIT
    end

    def synchronize(&blk)
      @lock.take
      value = @value.take
      blk value
      @value.put value
      @lock.put UNIT
    end
  end

end

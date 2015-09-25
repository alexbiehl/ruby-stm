module STM

  class MVar

    def initialize(value = nil)
      @empty   = value == nil
      @content = value
      @reader = Mutex.new
      @writer = Mutex.new
      @readCondVar = ConditionVariable.new
      @writeCondVar = ConditionVariable.new
    end

    def take
      @reader.synchronize {
        while @empty
          @readCondVar.wait(@reader)
        end
        @writer.synchronize {
          @empty = true
          @writeCondVar.signal
          @content
        }
      }
    end

    def read
      @reader.synchronize {
        while @empty
          @readCondVar.wait(@reader)
        end
        @readCondVar.signal
        @writer.synchronize {
          @content
        }
      }
    end

    def put(value)
      @writer.synchronize {
        while !@empty
          @writeCondVar.wait(@writer)
        end

        @reader.synchronize {
          @empty = false
          @content = value
          @readCondVar.signal
        }
      }
    end

    def tryPut(value)
      @writer.synchronize {
        if !@empty
          false
        else
          @reader.synchronize {
            @empty = false
            @content = value
            @readCondVar.signal
            true
          }
        end
      }
    end

    def tryTake
    @reader.synchronized {
        if empty
          nil
        else
          @writer.synchronized {
            @empty = true
            @writeCondVar.signal
            @content
          }
        end
      }
    end

    def write(value)
      @writer.synchronized {
        @reader.synchronized {
          if @empty
            @readCondVar.signal
          end
          @empty = false
          @content = o
        }
      }
    end

    def swap(value)
      @reader.synchronized {
        while @empty
          @readCondVar.wait(@reader)
        end
        @writer.synchronized {
          old = @content
          @content = value
          old
        }
      }
    end

    def isEmpty
      @reader.synchronized {
        @writer.synchronized {
          @empty
        }
      }
    end

  end

end

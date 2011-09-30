class Mapper
  
  attr_reader :columns, :rows, :filters
  
  def initialize(opts = {}, &block)
    @callback = block
    @columns  = opts[:columns] || []
    @rows     = opts[:rows] || []
    @filters  = opts[:filters] || []
    @rows.any? ? with_rows : without_rows
  end
  
  protected
  
  def with_rows
    #row_sums = Hash.new(0)
    data = {}
    async_counter = 0
    upto = columns.size * rows.size # number of iterations
    
    columns.each_with_index do |column, i|
      data[column] = {:column => column, :data => []}
      rows.each do |row|
        keys = [column, row, *filters].sort
        inter_key = 'i-' + keys.join('.')
        defredis = REDIS.sinterstore(inter_key, *keys)
        defredis.callback {|count|
          data[column][:data].push({:row => row, :count => count})
          async_counter += 1
          if async_counter == upto
            @callback.call data.values # done, return
          end
        }
        
        defredis.errback { |e|
          p [:err, inter_key, e]
        }
      end
    end
  end
  
  def without_rows
    data = {}
    async_counter = 0
    upto = columns.size # number of iterations
    
    columns.each do |column|
      data[column] = {:column => column}
      if filters.any?
        keys = [column, *filters].sort
        inter_key = 'i-' + keys.join('.')
        REDIS.sinterstore(inter_key, *keys) { |count|
          data[column][:count] = count
          async_counter += 1
          if async_counter == upto
            @callback.call data.values # done, return
          end
        }
      else # no filters, just do scard
        REDIS.scard(column) { |count|
          data[column][:count] = count
          async_counter += 1
          if async_counter == upto
            @callback.call data.values # done, return
          end
        }
      end
    end
  end
  
end
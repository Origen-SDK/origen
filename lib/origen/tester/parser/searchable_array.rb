module Origen
  module Tester
    module Parser
      class SearchableArray < ::Array
        def where(conditions)
          exact = conditions.delete(:exact)
          results = SearchableArray.new
          each do |item|
            if conditions.all? do |attr, val|
                 if val.is_a?(Array)
                   if exact
                     val.any? { |v| item.send(attr).to_s == v.to_s }
                   else
                     val.any? { |v| item.send(attr).to_s =~ /#{v.to_s}/ }
                   end
                 else
                   if exact
                     item.send(attr).to_s == val.to_s
                   else
                     item.send(attr).to_s =~ /#{val.to_s}/
                   end
                 end
               end
              results << item
            end
          end
          results
        end
      end
    end
  end
end

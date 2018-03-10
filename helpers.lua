local _, addon = ...

--
-- Helper functions
--
addon.helpers = {}

addon.helpers.print_r = function(t, indent, done)  -- TODO: delete
  done = done or {}
  indent = indent or ''
  local nextIndent -- Storage for next indentation value
  for key, value in pairs (t) do
    if type (value) == "table" and not done [value] then
      nextIndent = nextIndent or
          (indent .. string.rep(' ',string.len(tostring (key))+2))
          -- Shortcut conditional allocation
      done [value] = true
      print (indent .. "[" .. tostring (key) .. "] => Table {");
      print  (nextIndent .. "{");
      print_r (value, nextIndent .. string.rep(' ',2), done)
      print  (nextIndent .. "}");
    else
      print  (indent .. "[" .. tostring (key) .. "] => " .. tostring (value).."")
    end
  end
end

addon.helpers.table_clone = function(table)
    return {unpack(table)}
end

addon.helpers.multVec = function(vec, multiplicator)
    -- multiplies two vectors (arrays containing only numbers)
    for i, val in pairs(vec) do
        vec[i] = val * multiplicator 
    end
    return vec
end

addon.helpers.addVec = function(vec1, vec2)
    -- adds two vectors (arrays containing only numbers)
    vec = {}
    for i=1,table.getn(vec1) do 
        vec[i] = vec1[i] + vec2[i]
    end
    return vec
end

addon.helpers.round = function(num)
    return math.floor(num + 0.5)
end

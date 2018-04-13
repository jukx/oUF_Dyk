local _, addon = ...

--
-- Helper functions
--
addon.helpers = {}

function print_r(t, indent, done)  -- TODO: delete
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
addon.helpers.print_r = print_r

function table_clone(table)
    newtable = {}

    for k,v in pairs(table) do
        newtable[k] = v
    end
    return newtable
end
addon.helpers.table_clone = table_clone

addon.helpers.multVec = function(vec, multiplicator)
    -- multiplies a vector (arrays containing only numbers) with a scalar 
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

addon.helpers.lightenColor = function(color, degree)
    local newcolor = {}
    degree = degree or 1

    for i, val in pairs(color) do
        newcolor[i] = 1 - ((1 - val) * 1/(1 + degree))
    end

    return newcolor
end

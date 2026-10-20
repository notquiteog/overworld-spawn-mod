-- Wall time for network deadlines; CPU time stops while a request is idle.
return function()
  if love and love.timer and love.timer.getTime then return love.timer.getTime() end
  return os.time()
end

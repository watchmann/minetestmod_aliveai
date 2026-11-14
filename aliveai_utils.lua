-- CRITICAL CHECK: Does the bot still exist in the world?
if not self or not self.object or not self.object:get_pos() then
   aliveai_trader.user[name] = nil
   return
end
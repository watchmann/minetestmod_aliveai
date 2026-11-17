aliveai.tasks = {}

aliveai.task3=function(self)
    -- Safety check: ensure self exists and has required properties
    if not self then return end
    if not self.object then 
        self = nil return 
    end

    -- Check if we're in the right task state
    if self.task ~= "3" then
        self.task=""
        aliveai.rndwalk(self)
        return self
    end

    -- Get position safely
    local pos1=self.object:get_pos()
    if not pos1 then
        self.task=""
        aliveai.rndwalk(self)
        return self
    end

    -- Get target safely with nil checks
    local target = self.target
    if not target or not target:get_pos() then
        self.task=""
        aliveai.rndwalk(self)
        return self
    end

    -- Get target position safely
    local pos2=target:get_pos()
    if not pos2 then
        self.task=""
        aliveai.rndwalk(self)
        return self
    end

    -- Calculate distance safely
    local distance = aliveai.distance(self,target)
    if not distance then
        self.task=""
        aliveai.rndwalk(self)
        return self
    end

    -- Get hp values with defaults to prevent nil comparison
    local hp = self.hp or 0
    local target_hp = target.hp or 0

    -- SAFE COMPARISON: Check both values exist before comparing
    if hp and target_hp and hp > 0 and target_hp > 0 then
        -- Only attack if we can actually damage the target
        if hp > target_hp then
            -- Attack logic
            aliveai.lookat(self,pos2)
            aliveai.stand(self)
            target.punch(self,target_hp)
        end
    end

    -- Move toward target if within range
    if distance < (self.distance or 5) then
        aliveai.walk(self,pos2)
    end

    -- Task completion
    self.task=""
    aliveai.rndwalk(self)
    return self
end

-- FIXED: task_farming with proper nil protection
aliveai.task_farming=function(self)
    -- Ensure we have required fields
    if not aliveai.farming or not self.home or self.type~="npc" then return end

    -- Check if farming is active
    if not self.farming then
        -- Search for farming opportunities
        if not self.farming_name then
            local name
            local c=0
            for i, v in pairs(aliveai.farming) do
                -- Calculate required seeds
                c=((v.area*2)+1)*((v.area*2)+1)
                -- Check if we have seeds or creative mode
                if self.creative==1 or (self.inv and self.inv[v.seed] and self.inv[v.seed]>=c) then
                    name=i
                    break
                end
            end

            local p=aliveai.roundpos(self.object:get_pos())
            if not name or not p then return end

            -- Check ground type
            local ground_node = minetest.get_node({x=p.x,y=p.y-2,z=p.z})
            if not ground_node then return end
            if minetest.get_item_group(ground_node.name, aliveai.farming[name].ground_group)==0 then return end

            -- Build farming paths
            c=math.floor(c/2)*-1
            local a=aliveai.farming[name].area
            local paths={}
            local c_count=0

            for x=-a,a,1 do
            for z=-a,a,1 do
                local p1={x=p.x+x,y=p.y-1,z=p.z+z}
                local n=minetest.registered_nodes[minetest.get_node(p1).name]
                -- Check if placeable and has soil
                if n and n.buildable_to and not n.next_plant and
                minetest.get_node_light(p1)>14 and
                minetest.get_item_group(minetest.get_node({x=p.x+x,y=p.y-2,z=p.z+z}).name, "soil")>0 then
                    table.insert(paths,p1)
                    aliveai.showpath(p1,1)
                else
                    aliveai.showpath(p1,3)
                    c_count=c_count+1
                    if c_count>0 then return end
                end
            end
            end

            -- Start farming task
            self.farming_name=name
            self.farming=paths
            self.tmpfunc=self.step
            self.step=aliveai.task_farming
            self.time=0.5
            return self
        end

        -- Execute farming task
        if self.farming then
            local p=self.farming[1]
            if p then
                -- Get farming definitions
                local place=aliveai.farming[self.farming_name].seed
                local set=aliveai.farming[self.farming_name].ground
                local w=aliveai.roundpos(self.object:get_pos())

                -- Face the target position
                aliveai.lookat(self,p)

                -- Place the seed
                if aliveai.samepos(p,{x=w.x,y=w.y-1,z=w.z}) then
                    set=aliveai.farming[self.farming_name].source
                else
                    aliveai.place(self,p,place)
                    minetest.get_node_timer(p):start(math.random(166, 286))
                    minetest.swap_node(p,{name=place,param2=1})
                end

                -- Set ground type
                minetest.set_node({x=p.x,y=p.y-1,z=p.z},{name=set})

                -- Remove from farming list
                table.remove(self.farming,1)
                return self
            else
                -- Farming complete
                self.controlled=nil
                self.farming_name=nil
                self.farming=nil
                self.step=self.tmpfunc
                self.tmpfunc=nil
                aliveai.exitpath(self)
                return self
            end
        end
    end
end

-- FIXED: task_stay_at_home with proper nil protection
aliveai.task_stay_at_home=function(self)
    -- Ensure home exists
    if not self.home then return end

    -- If we have a path, follow it
    if self.path then 
        aliveai.path(self)
        return self
    end

    -- Check distance to home
    if self.distance then
        local d=aliveai.distance(self,self.home)
        if d then
            if d>self.distance*3 then
                -- Teleport home if too far
                aliveai.showstatus(self,"teleport home")
                self.object:set_pos(self.home)
                return self
            elseif d>self.distance*1.5 then
                -- Create path home
                local pos=self.object:get_pos()
                local p=aliveai.creatpath(self,pos,aliveai.roundpos(self.home))
                if p~=nil then
                    self.path=p
                    aliveai.showstatus(self,"go home")
                    return self
                else
                    -- Find new home position
                    local p=aliveai.neartarget(self,self.home,1,-10)
                    if p then
                        self.path=p
                        self.home=p
                        aliveai.showstatus(self,", change home pos, go home")
                        return self
                    end
                end
            end
        end
    end
end

-- FIXED: task_build with proper nil protection
aliveai.task_build=function(self)
    -- Ensure we're building and have no home
    if self.building~=1 or self.home then return end

    -- Setup for building
    if aliveai.enable_build==true and self.task=="" then
        aliveai.showstatus(self,"set up for build a home")
        self.build_step=1
        self.build_pos=""
        self.task="build"
        self.ignoremineitem=""
        self.ignoreminetime=0
        self.ignoreminetimer=200
        self.ignoreminechange=0
        self.taskstep=0
        aliveai.rndwalk(self,false)
    end

    -- Handle path following
    if self.path and self.done=="" and self.tmpgoto then
        aliveai.path(self)
        self.tmpgoto=self.tmpgoto+1
        if self.tmpgoto>=20 then 
            aliveai.exitpath(self)
            aliveai.showstatus(self,"path failed, mine")
        end
    end

    -- Task step logic with nil protection
    if self.taskstep<1 then
        -- Get build information
        aliveai.buildpath(self,true)
        if aliveai.haveneed(self) then
            self.done=""
            -- Go get resources
            if self.resources then
                local pos=self.object:get_pos()
                if pos then
                    pos.y=pos.y+1
                    local p=aliveai.creatpath(self,pos,self.resources,20)
                    if p then
                        self.path=p
                        aliveai.showstatus(self,"go to resources and mine",4)
                        return self
                    end
                end
            end
            -- Start mining
            self.mine={target={},status="search"}
            aliveai.showstatus(self,"mine",4)
        else
            self.taskstep=1
        end
        return self
    end

    if self.taskstep==1 then
        -- Find space to build
        self.findspace=true
        self.done=""
        aliveai.showstatus(self,"findspace",4)
        return self
    end

    if self.taskstep==2 then
        -- Build the structure
        self.build={}
        self.done=""
        aliveai.showstatus(self,"build",4)
        return self
    end

    if self.taskstep==3 then
        -- Build complete, set home if house
        if not self.home then
            local pos=self.object:get_pos()
            if pos then
                pos.y=pos.y+1
                self.home=pos
                aliveai.showstatus(self,"home set, build done",3)
            end
        else
            aliveai.showstatus(self,"status build done",3)
        end
        -- Clean up
        self.mine=nil
        self.need=nil
        self.ignore_item={}
        self.done=""
        self.task=""
        self.build_step=nil
        self.build_x=nil
        self.build_y=nil
        self.build_z=nil
        self.build_pos=nil
        self.house=nil
        self.taskstep=0
        return self
    end
end

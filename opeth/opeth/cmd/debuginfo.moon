class
	new: (@level, @no, @parent, @verbose = false, @modified = 0) =>
	fmt: => @parent and "#{@parent}->#{@level}.#{@no}" or "main"
	start_rec: => @rec = @modified
	stop_rec: => with @rec do @rec = nil
	mod_inc: => @modified += 1
	mod_dec: => @modified -= 1
	mod_add: (add) => @modified += add
	reset_modified: => @modified = 0
	print_modified: (module_name) =>
		if @verbose and @rec
			print "#{module_name}##{@fmt!}: #{@modified - @stop_rec!} modified"


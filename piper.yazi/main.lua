--- @since 25.5.31

local M = {}

local function fail(job, s)
	ya.preview_widget(job, ui.Text.parse(s):area(job.area):wrap(ui.Wrap.YES))
end

function M:peek(job)
	local child, err = Command("sh")
		:arg({ "-c", job.args[1], "sh", tostring(job.file.url) })
		:env("w", job.area.w)
		:env("h", job.area.h)
		:env("start", job.skip or 0)
		:env("end", (job.skip or 0) + job.area.h)
		:stdout(Command.PIPED)
		:stderr(Command.PIPED)
		:spawn()

	if not child then
		return fail(job, "sh: " .. err)
	end

	local i, outs, errs = 0, {}, {}
	while true do
		local next, event = child:read_line()

		if event == 1 then
			errs[#errs + 1] = next
		elseif event ~= 0 then
			break
		end
		outs[#outs + 1] = next
		i = i + 1
	end

	child:start_kill()
	if #errs > 0 then
		fail(job, table.concat(errs, ""))
	else
		ya.preview_widget(job, M.format(job, outs))
	end
end

function M:seek(job)
	local h = cx.active.current.hovered
	if not h or h.url ~= job.file.url then
		return
	end

	local step = math.floor(job.units * job.area.h / 10)
	step = step == 0 and ya.clamp(-1, job.units, 1) or step

	ya.emit("peek", {
		math.max(0, cx.active.preview.skip + step),
		only_if = job.file.url,
	})
end

function M.format(job, lines)
	local format = job.args.format
	if format ~= "url" then
		local s = table.concat(lines, ""):gsub("\r", ""):gsub("\t", string.rep(" ", rt.preview.tab_size))
		return ui.Text.parse(s):area(job.area)
	end

	for i = 1, #lines do
		lines[i] = lines[i]:gsub("[\r\n]+$", "")

		local icon = File({
			url = Url(lines[i]),
			cha = Cha({ kind = lines[i]:sub(-1) == "/" and 1 or 0 }),
		}):icon()

		if icon then
			lines[i] = ui.Line({ ui.Span(" " .. icon.text .. " "):style(icon.style), lines[i] })
		end
	end
	return ui.Text(lines):area(job.area)
end

return M

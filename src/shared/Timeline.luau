--!strict
-- Battle timeline codec: fixed 25-byte events in a buffer (server writes in Sim, client reads to play back).

local EVENT_SIZE = 25

local Timeline = {}

Timeline.Code = table.freeze({
	Spawn = 1, -- a = unit, b = monster index, c = x, d = max hp
	Stop = 2, -- a = unit, c = x
	Move = 3, -- a = unit
	Hit = 4, -- a = source, b = target, c = damage, d = target hp after
	Die = 5, -- a = unit
	Revive = 6, -- a = unit, d = hp
	Heal = 7, -- a = source, b = target, c = amount, d = target hp after
	Wave = 8, -- a = wave number
})

-- Heroes are units 1..4; monsters start here.
Timeline.MonsterBase = 101

export type Event = {
	T: number,
	Code: number,
	A: number,
	B: number,
	C: number,
	D: number,
}

export type Builder = {
	Buf: buffer,
	Count: number,
}

function Timeline.NewBuilder(): Builder
	return { Buf = buffer.create(EVENT_SIZE * 256), Count = 0 }
end

function Timeline.Push(b: Builder, t: number, code: number, a: number, bb: number, c: number, d: number)
	local offset = b.Count * EVENT_SIZE
	if offset + EVENT_SIZE > buffer.len(b.Buf) then
		local grown = buffer.create(buffer.len(b.Buf) * 2)
		buffer.copy(grown, 0, b.Buf, 0, offset)
		b.Buf = grown
	end
	buffer.writef32(b.Buf, offset, t)
	buffer.writeu8(b.Buf, offset + 4, code)
	buffer.writeu16(b.Buf, offset + 5, a)
	buffer.writeu16(b.Buf, offset + 7, bb)
	buffer.writef64(b.Buf, offset + 9, c)
	buffer.writef64(b.Buf, offset + 17, d)
	b.Count += 1
end

function Timeline.Finish(b: Builder): (buffer, number)
	local out = buffer.create(b.Count * EVENT_SIZE)
	buffer.copy(out, 0, b.Buf, 0, b.Count * EVENT_SIZE)
	return out, b.Count
end

function Timeline.Read(buf: buffer, index: number): Event
	local offset = (index - 1) * EVENT_SIZE
	return {
		T = buffer.readf32(buf, offset),
		Code = buffer.readu8(buf, offset + 4),
		A = buffer.readu16(buf, offset + 5),
		B = buffer.readu16(buf, offset + 7),
		C = buffer.readf64(buf, offset + 9),
		D = buffer.readf64(buf, offset + 17),
	}
end

-- Validates a received buffer's size against its claimed event count.
function Timeline.IsValid(buf: unknown, count: unknown): boolean
	return typeof(buf) == "buffer" and type(count) == "number" and buffer.len(buf) == count * EVENT_SIZE
end

return table.freeze(Timeline)

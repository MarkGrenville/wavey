
class @Range
	constructor: (@a, @b = @a, @track_a, @track_b = @track_a)->
	# @TODO: rename start/end to startTime/endTime
	# and maybe have start/end methods that return a new Range at the start/end
	start: -> Math.min(@a, @b)
	end: -> Math.max(@a, @b)
	length: -> @end() - @start()
	containsTime: (time)-> @start() <= time <= @end()
	startTrackIndex: -> Math.min(@track_a, @track_b)
	endTrackIndex: -> Math.max(@track_a, @track_b)
	containsTrackIndex: (track_index)-> @startTrackIndex() <= track_index <= @endTrackIndex()
	
	contents: (tracks)->
		# return stuff from tracks within this range
		
		stuff = {version: AudioEditor.stuff_version, length: @length(), rows: []}
		
		for track, track_index in tracks when track.type is "audio" and @containsTrackIndex track_index
			clips = []
			for clip in track.clips
				buffer = AudioClip.audio_buffers[clip.audio_id]
				unless buffer?
					InfoBar.warn "Not all selected tracks have finished loading."
					return
				clip_end = clip.time + clip.length
				clip_start = clip.time
				if @start() < clip_end and @end() > clip_start
					# clip and selection overlap
					if @start() <= clip_start and @end() >= clip_end
						# clip is entirely contained within selection
						clips.push
							id: GUID()
							audio_id: clip.audio_id
							time: clip_start - @start()
							length: clip.length
							offset: clip.offset
					else if @start() > clip_start and @end() < clip_end
						# selection is entirely within clip
						clips.push
							id: GUID()
							audio_id: clip.audio_id
							time: 0
							length: @length()
							offset: clip.offset - clip_start + @start()
					else if @start() < clip_end <= @end()
						# selection overlaps end of clip
						clips.push
							id: GUID()
							audio_id: clip.audio_id
							time: 0
							length: clip_end - @start()
							offset: clip.offset - clip_start + @start()
					else if @start() <= clip_start < @end()
						# selection overlaps start of clip
						clips.push
							id: GUID()
							audio_id: clip.audio_id
							time: clip_start - @start()
							length: @end() - clip_start
							offset: clip.offset
			stuff.rows.push clips
		
		stuff
	
	collapse: (tracks)->
		# modify tracks, return a collapsed Range
		
		for track, track_index in tracks when track.type is "audio" and @containsTrackIndex track_index
			clips = []
			for clip in track.clips
				buffer = AudioClip.audio_buffers[clip.audio_id]
				unless buffer?
					InfoBar.warn "Not all selected tracks have finished loading."
					return
				clip_end = clip.time + clip.length
				clip_start = clip.time
				if @start() < clip_end and @end() > clip_start
					if @start() > clip_start
						clips.push
							id: GUID()
							audio_id: clip.audio_id
							time: clip_start
							length: @start() - clip_start
							offset: clip.offset
					if @end() < clip_end
						clips.push
							id: GUID()
							audio_id: clip.audio_id
							time: @start()
							length: clip_end - @end()
							offset: clip.offset + @end() - clip_start
				else
					if clip_start >= @end()
						clip.time -= @length()
					clips.push clip
			track.clips = clips
		
		new Range @start(), @start(), @startTrackIndex(), @endTrackIndex()
	
	# maybe there should be a class for "Stuff" (@TODO?)
	# this should probably be Stuff::insert
	@insert: (stuff, tracks, insertion_position, insertion_track_start_index)->
		
		console.log "insert", stuff, insertion_position, insertion_track_start_index
		
		insertion_length = stuff.length
		insertion_track_end_index = insertion_track_start_index + stuff.rows.length - 1
		
		for track in tracks.slice(insertion_track_start_index, insertion_track_end_index + 1) when track.type is "audio"
			clips = []
			for clip in track.clips
				if clip.time >= insertion_position
					clip.time += insertion_length
					clips.push clip
				else if clip.time + clip.length > insertion_position
					clips.push
						id: GUID()
						audio_id: clip.audio_id
						time: clip.time
						length: insertion_position - clip.time
						offset: clip.offset
					clips.push
						id: GUID()
						audio_id: clip.audio_id
						time: insertion_position + insertion_length
						length: clip.length - (insertion_position - clip.time)
						offset: clip.offset + insertion_position - clip.time
				else
					clips.push clip
			track.clips = clips
		
		for clips, i in stuff.rows
			track = tracks[insertion_track_start_index + i]
			if not track? and clips.length
				track = {id: GUID(), type: "audio", clips: []}
				tracks.push track
			for clip in clips
				clip.time += insertion_position
				clip.id = GUID()
				track.clips.push clip
				console.log "add", clip, "to", track
		
		end = insertion_position + insertion_length
		new Range end, end, insertion_track_start_index, insertion_track_end_index
	
	@drag: (range, {to, toTrackIndex})->
		new Range range.a, Math.max(0, to), range.track_a, Math.max(0, toTrackIndex)
	
	@fromJSON: (range)->
		new Range range.a, range.b, range.track_a, range.track_b
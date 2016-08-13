
class @TracksArea extends E.Component
	render: ->
		{tracks, position, position_time, scale, playing, editor} = @props
		
		drag = (range, to_position, to_track_id)=>
			sorted_tracks = editor.get_sorted_tracks tracks
			from_track = track for track in sorted_tracks when track.id is range.firstTrackID()
			to_track = track for track in sorted_tracks when track.id is to_track_id
			include_tracks =
				if sorted_tracks.indexOf(from_track) < sorted_tracks.indexOf(to_track)
					sorted_tracks.slice sorted_tracks.indexOf(from_track), sorted_tracks.indexOf(to_track) + 1
				else
					sorted_tracks.slice sorted_tracks.indexOf(to_track), sorted_tracks.indexOf(from_track) + 1
			new Range range.a, Math.max(0, to_position), [range.firstTrackID()].concat(track.id for track in include_tracks when track.id isnt range.firstTrackID())
		
		document_is_basically_empty = yes
		for track in tracks when track.type isnt "beat"
			document_is_basically_empty = no
		
		
		# TODO: decide if this is the ideal or what
		document_width_padding = window.innerWidth/2
		
		# FIXME: XXX: HACK: this is Not the Way
		HACK_InfoBar_warn = InfoBar.warn
		InfoBar.warn = ->
		document_width = editor.get_max_length() * scale + document_width_padding
		InfoBar.warn = HACK_InfoBar_warn
		
		E ".tracks-area",
			onMouseDown: (e)=>
				return if e.isDefaultPrevented()
				return if closest(e.target, "p")
				unless e.button > 0
					e.preventDefault()
				if e.target is React.findDOMNode(@)
					e.preventDefault()
					editor.deselect()
			E ".track-controls-area",
				key: "track-controls-area"
				for track in tracks
					switch track.type
						when "beat"
							E TrackControls, {key: track.id, track, scale, editor}
						when "audio"
							E TrackControls, {key: track.id, track, scale, editor}
						else
							# This is needed for aligning the track-controls
							# Could probably use aria-controls or something instead
							E ".track-controls.no-track-controls", key: track.id
			
			E ".track-content-area",
				key: "track-content-area"
				# @TODO: touch support
				# @TODO: double click to select either to the bounds of adjacent audio clips or everything on the track
				# @TODO: drag and drop the selection?
				# @TODO: better overall drag and drop feedback
				# @TODO: scroll by dragging to the left or right edges
				onMouseDown: (e)=>
					# FIXME: WET, TODO: DRY, NOTE: this was copy/pasted into AudioTrack's select_at_mouse
					return unless e.button is 0
					track_content_el = closest(e.target, ".track-content")
					track_content_area_el = closest(e.target, ".track-content-area")
					if closest(track_content_el, ".add-track, .unknown-track")
						editor.deselect()
						return
					unless track_content_el
						unless closest(e.target, ".track-controls")
							e.preventDefault()
							editor.deselect()
						return
					e.preventDefault()
					
					position_at = (e)=>
						rect = track_content_el.getBoundingClientRect()
						(e.clientX - rect.left + track_content_area_el.scrollLeft) / scale
					
					track_id_at = (e)=>
						track_el = closest e.target, ".track"
						if track_el and track_el.dataset.trackId
							track_el.dataset.trackId
						else
							track_els = React.findDOMNode(@).querySelectorAll ".track"
							nearest_track_el = track_els[0]
							distance = Infinity
							for track_el in track_els when track_el.dataset.trackId
								rect = track_el.getBoundingClientRect()
								_distance = Math.abs(e.clientY - (rect.top + rect.height / 2))
								if _distance < distance
									nearest_track_el = track_el
									distance = _distance
							nearest_track_el.dataset.trackId
					
					position = position_at e
					track_id = track_id_at e
					
					if e.shiftKey
						editor.select drag @props.selection, position, track_id
					else
						editor.select new Range position, position, [track_id]
					
					mouse_moved_timewise = no
					mouse_moved_trackwise = no
					starting_clientX = e.clientX
					window.addEventListener "mousemove", onMouseMove = (e)=>
						if Math.abs(e.clientX - starting_clientX) > 5
							mouse_moved_timewise = yes
						if track_id_at(e) isnt track_id
							mouse_moved_trackwise = yes
						if @props.selection and (mouse_moved_timewise or mouse_moved_trackwise)
							drag_position = if mouse_moved_timewise then position_at(e) else position
							drag_track_id = if mouse_moved_trackwise then track_id_at(e) else track_id
							editor.select drag @props.selection, drag_position, drag_track_id
							e.preventDefault()
					
					window.addEventListener "mouseup", onMouseUp = (e)=>
						window.removeEventListener "mouseup", onMouseUp
						window.removeEventListener "mousemove", onMouseMove
						unless mouse_moved_timewise
							editor.seek position
				
				E ".document-width",
					key: "document-width"
					style:
						width: document_width
						# NOTE: it apparently needs some height to cause scrolling
						flex: "0 0 1px"
						# and we don't want some random extra height somewhere
						# so we at least try to put it at the bottom
						order: 100000
				
				for track in tracks
					switch track.type
						when "beat"
							E BeatTrack, {key: track.id, track, scale, editor}
						when "audio"
							E AudioTrack, {
								key: track.id, track, scale
								position, position_time, playing, editor
								selection: (@props.selection if @props.selection?.containsTrack track)
							}
						else
							E UnknownTrack, {key: track.id, track, scale, editor}
				
				E AddTrack, {key: "add-track", editor},
					if document_is_basically_empty
						E ".getting-started",
							E "p", "To get started, hit record above or add some tracks below."
	
	animate: ->
		# {scale} = @props
		@animation_frame = requestAnimationFrame => @animate()
		# if @props.playing
		# 	if @refs.position_indicator
		# 		position = @props.position + actx.currentTime - @props.position_time
		# 		@refs.position_indicator.getDOMNode().style.left = "#{scale * position}px"
		
		# TODO: animate tracks ordering and the position indicator here
		
		tracks_area_el = React.findDOMNode(@)
		# tracks_area_el.style.width = "10000px"
		tracks_area_rect = tracks_area_el.getBoundingClientRect()
		
		tracks_content_area_el = tracks_area_el.querySelector(".track-content-area")
		# tracks_content_area_el.style.width = "1000px"
		
		track_els = tracks_area_el.querySelectorAll(".track")
		track_controls_els = tracks_area_el.querySelectorAll(".track-controls")
		for track_controls_el, i in track_controls_els
			track_el = track_els[i]
			track_rect = track_el.getBoundingClientRect()
			track_controls_el.style.top = "#{track_rect.top - tracks_area_rect.top + parseInt(getComputedStyle(track_el).paddingTop)}px"
		
		scroll_x = tracks_content_area_el.scrollLeft
		for track_el in track_els # when track_el.classList.contains("audio-track")
			track_content_el = track_el.querySelector(".track-content > *")
			track_el.style.transform = "translateX(#{scroll_x}px)"
			if track_el.classList.contains("audio-track") or track_el.classList.contains("beat-track")
				track_content_el.style.transform = "translateX(#{-scroll_x}px)"
	
	componentWillUpdate: (next_props, next_state)=>
		# for transitioning track positions
		@last_track_rects = null
		# @TODO: transition removing/unremoving tracks
		if @props.tracks.length is next_props.tracks.length
			for track_current, track_index in @props.tracks
				track_future = next_props.tracks[track_index]
				if track_future.pinned isnt track_current.pinned
					track_els = React.findDOMNode(@).querySelectorAll(".track")
					@last_track_rects = (track_el.getBoundingClientRect() for track_el in track_els)
	
	componentDidUpdate: (last_props, last_state)=>
		# transition track positions
		# TODO: handle starting transitions while already transitioning (probably use a rAF loop)
		transition_seconds = 0.5
		if @last_track_rects
			track_els = React.findDOMNode(@).querySelectorAll(".track")
			for track_el, track_index in track_els
				current_rect = track_el.getBoundingClientRect()
				last_rect = @last_track_rects[track_index]
				track_el.style.transform = "translateY(#{last_rect.top - current_rect.top}px)"
				do (track_el)->
					setTimeout ->
						track_el.style.transition = "transform #{transition_seconds}s ease"
						setTimeout ->
							track_el.style.transform = "translateY(0)"
							setTimeout ->
								track_el.style.transition = ""
							, transition_seconds * 1000
	
	componentDidMount: ->
		@animate()
	
	componentWillUnmount: ->
		cancelAnimationFrame @animation_frame

extends "res://tests/sanctum_combat.gd"
## Short rendered observation of the first native encounter. No resets,
## enemy freezing, extra resources or injected combat prerequisites.
var frame_clock:=0.0
var frames:Array=[]
var ended:=false
var audio_capture:AudioEffectCapture
var audio_started:=false
var audio_saved:=false
var audio_wall_start:=0.0
var audio_wall_end:=0.0

func observe(p:Player,delta:float)->void:
	super.observe(p,delta)
	if elapsed>=7.0 and not audio_started:
		audio_started=true
		audio_wall_start=Time.get_ticks_usec()/1000000.0
		audio_capture=AudioEffectCapture.new()
		audio_capture.buffer_length=60.0
		AudioServer.add_bus_effect(0,audio_capture)
	if elapsed>17.0 and audio_started and not audio_saved:
		audio_saved=true
		audio_wall_end=Time.get_ticks_usec()/1000000.0
		save_audio()
	if elapsed>=7.0 and elapsed<=17.0:
		frame_clock+=delta
		if frame_clock>=.10:
			frame_clock=0.0
			capture_frame(elapsed)
	if elapsed>=55.0 and not ended:
		finish("sample_complete")

func capture_frame(at:float)->void:
	await RenderingServer.frame_post_draw
	if ended:return
	var picture:=get_viewport().get_texture().get_image()
	picture.resize(960,540,Image.INTERPOLATE_LANCZOS)
	var name:="frame_%05d.png"%frames.size()
	picture.save_png(out_dir+"/"+name)
	frames.append({"file":name,"seconds":at,"wall_seconds":Time.get_ticks_usec()/1000000.0})

func save_audio()->void:
	var samples:PackedVector2Array=audio_capture.get_buffer(audio_capture.get_frames_available())
	var pcm:=PackedByteArray()
	pcm.resize(samples.size()*4)
	for i in samples.size():
		pcm.encode_s16(i*4,clampi(roundi(samples[i].x*32767),-32768,32767))
		pcm.encode_s16(i*4+2,clampi(roundi(samples[i].y*32767),-32768,32767))
	var wave:=AudioStreamWAV.new()
	wave.format=AudioStreamWAV.FORMAT_16_BITS
	wave.mix_rate=int(AudioServer.get_mix_rate())
	wave.stereo=true;wave.data=pcm
	wave.save_to_wav(out_dir+"/native_mix.wav")
	AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)

func finish(reason:String)->void:
	if ended:return
	ended=true
	forward(false)
	var discarded:int=audio_capture.get_discarded_frames() if audio_capture else -1
	var passed:=reason=="sample_complete" and death_count==0 and teleports==0 and frames.size()>40 and discarded==0
	var report:Dictionary={"kind":"partial_rendered_native_encounter","pass":passed,"reason":reason,"elapsed_sim_seconds":elapsed,"conditions":"same native level15 first-pull fixture as the full run; no injected healing/resources, no frozen mobs","frames":frames,"arrived":index,"teleport_samples":teleports,"ally_deaths":death_count,"kills":kills,"encounters":encounters,"casts":cast_counts}
	report["audio_wall_start"]=audio_wall_start
	report["audio_wall_end"]=audio_wall_end
	report["audio_discarded_frames"]=discarded
	FileAccess.open(out_dir+"/visual_sample.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("VISUAL SAMPLE pass=",passed," frames=",frames.size()," elapsed=",elapsed," reason=",reason)
	get_tree().quit(0 if passed else 1)

extends Control

var amount := 0.0
var caption := ""
var accent := Color("#f1cd80")

func update_progress(value: float, title: String, color: Color) -> void:
	amount = clampf(value,0,1)
	caption = title
	accent = color
	queue_redraw()

func content_rect() -> Rect2:
	var width := maxf(130,caption_width()+30)
	return Rect2(-width/2,-33,width,99)

func caption_width() -> float:
	return ThemeDB.fallback_font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var title_width := caption_width()
	draw_circle(Vector2.ZERO,33,Color("#253941"))
	draw_arc(Vector2.ZERO,28,-PI/2,TAU-PI/2,64,Color("#50636a"),6,true)
	if amount>0:
		draw_arc(Vector2.ZERO,28,-PI/2,amount*TAU-PI/2,64,accent,6,true)
	var percent := "%d%%" % floori(amount*100)
	var number_width := font.get_string_size(percent,HORIZONTAL_ALIGNMENT_LEFT,-1,17).x
	draw_string(font,Vector2(-number_width/2,6),percent,HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("#fff4dc"))
	var bounds := content_rect()
	draw_rect(Rect2(bounds.position.x,39,bounds.size.x,bounds.end.y-39),Color("#253941"))
	draw_string(font,Vector2(-title_width/2,58),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("#fff4dc"))

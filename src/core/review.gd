class_name Review
extends RefCounted

var id := 0
var stars := 5
var text_index := 0
var author_index := 0
var posted_at := 0.0
var forced := false
var lawsuits := 0


func _init(p_id: int = 0, p_stars: int = 5, p_text_index: int = 0, p_author_index: int = 0, p_posted_at: float = 0.0) -> void:
	id = p_id
	stars = clampi(p_stars, 1, 5)
	text_index = p_text_index
	author_index = p_author_index
	posted_at = p_posted_at


func is_negative() -> bool:
	return stars <= GameConfig.REVIEW_NEGATIVE_MAX_STARS and not forced


func drain_weight() -> float:
	if not is_negative():
		return 0.0
	return float(GameConfig.REVIEW_NEGATIVE_MAX_STARS + 1 - stars) / float(GameConfig.REVIEW_NEGATIVE_MAX_STARS)


func force_praise(p_text_index: int) -> void:
	stars = 5
	forced = true
	text_index = p_text_index


func can_be_sued() -> bool:
	return not forced and lawsuits < GameConfig.MAX_REVIEW_LAWSUITS


func lawsuits_left() -> int:
	return maxi(0, GameConfig.MAX_REVIEW_LAWSUITS - lawsuits)


func needs_ad_lawsuit() -> bool:
	return not forced and lawsuits >= GameConfig.MAX_REVIEW_LAWSUITS


func downgrade(p_text_index: int) -> void:
	lawsuits += 1
	stars = maxi(1, stars - 1)
	text_index = clampi(p_text_index, 0, GameConfig.review_texts(stars) - 1)


func text_key() -> String:
	if forced:
		return "REVIEW_FORCED_%d" % (text_index + 1)
	return "REVIEW_TEXT_%d_%d" % [stars, text_index + 1]


func author_key() -> String:
	return "REVIEW_AUTHOR_%d" % (author_index + 1)


func to_dict() -> Dictionary:
	return {"id": id, "stars": stars, "text": text_index, "author": author_index, "at": posted_at, "forced": forced, "lawsuits": lawsuits}


static func from_dict(data: Variant) -> Review:
	if not data is Dictionary:
		return null
	var review := Review.new(
		maxi(0, int(data.get("id", 0))),
		clampi(int(data.get("stars", 5)), 1, 5),
		0,
		clampi(int(data.get("author", 0)), 0, GameConfig.REVIEW_AUTHORS - 1),
		maxf(0.0, float(data.get("at", 0.0)))
	)
	review.forced = bool(data.get("forced", false))
	review.lawsuits = clampi(int(data.get("lawsuits", 0)), 0, GameConfig.MAX_REVIEW_LAWSUITS)
	if review.forced:
		review.stars = 5
		review.text_index = clampi(int(data.get("text", 0)), 0, GameConfig.REVIEW_FORCED_TEXTS - 1)
	else:
		review.text_index = clampi(int(data.get("text", 0)), 0, GameConfig.review_texts(review.stars) - 1)
	return review

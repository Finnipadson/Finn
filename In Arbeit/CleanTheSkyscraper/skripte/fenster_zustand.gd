class_name FensterZustand
extends RefCounted
# Wie dreckig ist jedes Fenster? Zwei Texturen für den Glas-Shader:
#  - zustand (RG8, eine Zeile pro Stockwerk, ein Pixel pro Fenster): R = Dreckmenge (0 = sauber), G = Wisch-Slot + 1 (0 = keiner)
#  - wisch (R8-Atlas): für Fenster, an denen gerade geputzt wird, eine feine Maske (1 = dreckig, 0 = schon gewischt)
# So bleibt es auch bei 25.000 Fenstern schnell: feine Masken gibt es nur für die paar Fenster vor der Gondel.

const SLOT_W := 64
const SLOT_H := 128
const SLOTS_X := 16
const SLOTS_Y := 4
const SAUBER_AB := 0.95      # ab so viel gewischter Fläche zählt das Fenster als sauber

var turm: Turm
var breite := 0
var zustand: Image
var zustand_tex: ImageTexture
var atlas: Image
var atlas_tex: ImageTexture
var slots := {}                       # Fenster-Nummer -> Slot
var slot_fenster := PackedInt32Array() # Slot -> Fenster-Nummer (-1 = frei)
var slot_ort := []                     # Slot -> Vector2i(spalte, stockwerk)
var slot_dreck := PackedInt32Array()   # dreckige Pixel im Slot
var slot_zeit := PackedInt64Array()
var sauber := PackedByteArray()        # 1 = sauber
var sauber_zahl := 0
var atlas_neu := false
var zustand_neu := false

func _init(t: Turm) -> void:
	turm = t
	for f in Turm.STOCKWERKE:
		breite = maxi(breite, turm.fenster_pro_stock[f] + 1)
	zustand = Image.create(breite, Turm.STOCKWERKE, false, Image.FORMAT_RG8)
	for f in Turm.STOCKWERKE:
		for s in breite:
			var d := 0.0
			if s < turm.fenster_pro_stock[f]:
				d = 0.55 + 0.45 * _hash(f, s)
			zustand.set_pixel(s, f, Color(d, 0, 0))
	zustand_tex = ImageTexture.create_from_image(zustand)
	atlas = Image.create(SLOT_W * SLOTS_X, SLOT_H * SLOTS_Y, false, Image.FORMAT_R8)
	atlas.fill(Color(1, 1, 1))
	atlas_tex = ImageTexture.create_from_image(atlas)
	var n := SLOTS_X * SLOTS_Y
	slot_fenster.resize(n)
	slot_fenster.fill(-1)
	slot_dreck.resize(n)
	slot_zeit.resize(n)
	slot_ort.resize(n)
	sauber.resize(turm.fenster_gesamt)

func _hash(f: int, s: int) -> float:
	var x := sin(f * 127.1 + s * 311.7) * 43758.5453
	return x - floor(x)

# Shader-Parameter für das Turmglas setzen
func verbinde(m: ShaderMaterial) -> void:
	m.set_shader_parameter("zustand", zustand_tex)
	m.set_shader_parameter("wisch", atlas_tex)
	m.set_shader_parameter("zustand_px", Vector2(breite, Turm.STOCKWERKE))
	m.set_shader_parameter("slots", Vector2(SLOTS_X, SLOTS_Y))
	m.set_shader_parameter("slot_px", Vector2(SLOT_W, SLOT_H))

func ist_sauber(f: int, spalte: int) -> bool:
	if spalte < 0 or spalte >= turm.fenster_pro_stock[f]:
		return true
	return sauber[turm.fenster_basis[f] + spalte] == 1

# Wischt eine Ellipse ins Fenster (spalte, f). mx/my = Mitte in Fenster-Anteilen (0..1, y nur Glasbereich),
# rx/ry = Radius in Anteilen. Gibt true zurück, wenn das Fenster dadurch sauber geworden ist.
func wische(f: int, spalte: int, mx: float, my: float, rx: float, ry: float) -> bool:
	if f < 0 or f >= Turm.STOCKWERKE or spalte < 0 or spalte >= turm.fenster_pro_stock[f]:
		return false
	var id := turm.fenster_basis[f] + spalte
	if sauber[id] == 1:
		return false
	var slot := _slot_fuer(id, f, spalte)
	var ox := (slot % SLOTS_X) * SLOT_W
	var oy := (slot / SLOTS_X) * SLOT_H
	var cx := mx * SLOT_W
	var cy := my * SLOT_H
	var prx := maxf(rx * SLOT_W, 0.5)
	var pry := maxf(ry * SLOT_H, 0.5)
	for py in range(maxi(0, int(cy - pry)), mini(SLOT_H, int(cy + pry) + 1)):
		for px in range(maxi(0, int(cx - prx)), mini(SLOT_W, int(cx + prx) + 1)):
			var dx := (px + 0.5 - cx) / prx
			var dy := (py + 0.5 - cy) / pry
			if dx * dx + dy * dy <= 1.0 and atlas.get_pixel(ox + px, oy + py).r > 0.5:
				atlas.set_pixel(ox + px, oy + py, Color(0, 0, 0))
				slot_dreck[slot] -= 1
	atlas_neu = true
	slot_zeit[slot] = Time.get_ticks_msec()
	if slot_dreck[slot] <= int(SLOT_W * SLOT_H * (1.0 - SAUBER_AB)):
		_fertig(id, f, spalte, slot)
		return true
	return false

# Anteil, der an einem Fenster schon geschafft ist (0..1)
func fortschritt(f: int, spalte: int) -> float:
	if ist_sauber(f, spalte):
		return 1.0
	var id := turm.fenster_basis[f] + spalte
	if not slots.has(id):
		return 0.0
	return 1.0 - float(slot_dreck[slots[id]]) / (SLOT_W * SLOT_H)

func _slot_fuer(id: int, f: int, spalte: int) -> int:
	if slots.has(id):
		return slots[id]
	var slot := slot_fenster.find(-1)
	if slot < 0:
		# alle belegt: den am längsten nicht benutzten freigeben, sein Fortschritt geht als Dreckmenge zurück
		slot = 0
		for i in slot_zeit.size():
			if slot_zeit[i] < slot_zeit[slot]:
				slot = i
		var alt: Vector2i = slot_ort[slot]
		var rest := float(slot_dreck[slot]) / (SLOT_W * SLOT_H)
		var c := zustand.get_pixel(alt.x, alt.y)
		zustand.set_pixel(alt.x, alt.y, Color(c.r * rest, 0, 0))
		slots.erase(slot_fenster[slot])
	slot_fenster[slot] = id
	slot_ort[slot] = Vector2i(spalte, f)
	slots[id] = slot
	slot_dreck[slot] = SLOT_W * SLOT_H
	atlas.fill_rect(Rect2i((slot % SLOTS_X) * SLOT_W, (slot / SLOTS_X) * SLOT_H, SLOT_W, SLOT_H), Color(1, 1, 1))
	var c2 := zustand.get_pixel(spalte, f)
	zustand.set_pixel(spalte, f, Color(c2.r, (slot + 1) / 255.0, 0))
	zustand_neu = true
	return slot

func _fertig(id: int, f: int, spalte: int, slot: int) -> void:
	sauber[id] = 1
	sauber_zahl += 1
	zustand.set_pixel(spalte, f, Color(0, 0, 0))
	zustand_neu = true
	slots.erase(id)
	slot_fenster[slot] = -1

# Einmal pro Bild: geänderte Texturen auf die Grafikkarte schicken
func aktualisieren() -> void:
	if atlas_neu:
		atlas_tex.update(atlas)
		atlas_neu = false
	if zustand_neu:
		zustand_tex.update(zustand)
		zustand_neu = false

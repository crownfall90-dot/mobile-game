# Ванная — отдельные предметы, 27.09.2026

Каждый предмет — самостоятельный PNG в `art/act1/bath/`, не часть фона или атласа.
Генератор: встроенный image_gen с transparent_background=true. Стилевая ссылка:
`bath_sink_fixed.png`. Равномерное уменьшение и прозрачные поля выполнены ffmpeg;
форма предметов не растягивалась. Размер и альфа проверены.

| Файл | PNG | Предлагаемый rect в сцене | z |
|---|---|---|---|
| bath_mirror.png | 220×280 | [235,560,150,191] | 0 |
| bath_towel.png | 140×260 | [118,630,84,156] | 1 |
| bath_shelf.png | 300×140 | [488,491,200,93] | 1 |
| bath_duck.png | 90×80 | [623,859,45,40] | 2 |
| bath_mat.png | 320×120 | [474,1050,220,83] | 0 |
| bath_basket.png | 200×220 | [35,1135,140,154] | 2 |

Зеркало над раковиной, полотенце рядом; полка выше ванны и ремонтной зоны кафеля.
Уточка опирается на правый бортик ванны. Коврик лежит перед ванной; корзина слева
от семьи на полу. Фигуры, проходы и ремонтные предметы остаются читаемыми.

`preview.gd` добавляет только эти props в копию данных в памяти и включает volatile
профиль. Игровой act1.json не меняется. Проверены реальные Godot-снимки 450×800 и
450×1000. Это предложение расстановки для Claude, ещё не подключение в APK.
Для старта/сломанной ванной Claude должен согласовать доступность предметов и действий.

## Промпты предметов

Общее: separate isolated Vita cozy cartoon mobile game sprite; clean dark warm-brown
outline, broad simple forms, soft restrained painted shading, upper-left warm light;
no photorealism, text, scenery or external shadow; genuine transparent alpha.

- Mirror: modest oval wall mirror, plain honey-brown wooden frame, muted blue-grey
  glass and two pale reflective streaks, no reflected people or room; upright near
  frontal view, slightly from right, compatible with an eye-level corner room.
- Towel: sage-green cloth with narrow cream stripe, hanging from small bronze wall
  hook; broad folds, rounded cloth corners, vertical silhouette, whole hook visible.
- Shelf: one honey-brown plank with two small brackets; exactly three short plain
  toiletries on it (sage bottle, cream jar, blue bottle); right-wall perspective,
  front edge rising slightly toward right, vertical bottles, no labels.
- Duck: small yellow rubber duck, orange beak facing left, black eye, raised tail,
  stable bottom; slight three-quarter side view, no water, reads at90×80.
- Mat: flat sage oval with cream inset border, strongly foreshortened, thin front
  edge, no tassels/rolled corners. Follow-up edit removed diffuse external shadow;
  final tight crop uses the subject alpha bounds. No hand-painted alpha mask.
- Basket: modest honey-brown wicker basket, two handles, cream and pale-blue cloth
  peeking out; three-quarter view, stable bottom, simplified broad woven bands.

Source generation filenames under the chat's generated_images directory:
mirror `exec-9b1b5e28-b203-4c4b-8fc5-4114951ab2b1.png`;
towel `exec-b58a8c61-2f9e-4c3a-a046-de5e6710b397.png`;
shelf `exec-7e73a0e2-5015-44de-8aab-4a4500580ce9.png`;
duck `exec-1660455f-76fa-4357-bbd7-d81b0dff67bc.png`;
mat final `exec-e3e9d85d-5bf5-4d9a-a4bb-a275c05ea095.png`;
basket `exec-56b7a139-6626-4ac8-8044-c535dde7f148.png`.

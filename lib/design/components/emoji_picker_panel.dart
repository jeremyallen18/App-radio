import 'package:flutter/material.dart';
import '../tokens/colors.dart';
import '../tokens/spacing.dart';

/// Una categoría de emojis, con su ícono de pestaña y una lista de
/// entradas (emoji + palabras clave en español para poder buscarlo).
class _EmojiCategory {
  const _EmojiCategory(this.label, this.icon, this.entries);
  final String label;
  final IconData icon;
  final List<_EmojiEntry> entries;
}

class _EmojiEntry {
  const _EmojiEntry(this.char, this.keywords);
  final String char;

  /// Palabras sueltas en español para que la búsqueda encuentre el emoji
  /// aunque el usuario no escriba el nombre exacto (p. ej. "risa" -> 😂).
  final String keywords;
}

/// Panel de selección de emojis al estilo WhatsApp: categorías en
/// pestañas + buscador. Se usa dentro de [MessageComposer], que lo
/// muestra/oculta al tocar el botón de emoji.
///
/// No depende de ningún paquete externo de emoji: usa caracteres Unicode
/// directamente, así que solo hace falta que la fuente del sistema los
/// sepa dibujar (igual que cualquier teclado emoji nativo).
class EmojiPickerPanel extends StatefulWidget {
  const EmojiPickerPanel({super.key, required this.onEmojiSelected});

  final ValueChanged<String> onEmojiSelected;

  static const double height = 260;

  @override
  State<EmojiPickerPanel> createState() => _EmojiPickerPanelState();
}

class _EmojiPickerPanelState extends State<EmojiPickerPanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  static final List<_EmojiCategory> _categories = [
    _EmojiCategory('Caritas', Icons.emoji_emotions_outlined, [
      const _EmojiEntry('😀', 'sonrisa feliz contento'),
      const _EmojiEntry('😃', 'sonrisa feliz contento'),
      const _EmojiEntry('😄', 'sonrisa feliz risa'),
      const _EmojiEntry('😁', 'sonrisa feliz dientes'),
      const _EmojiEntry('😆', 'risa carcajada'),
      const _EmojiEntry('😅', 'risa nervioso sudor'),
      const _EmojiEntry('🤣', 'risa carcajada llorar'),
      const _EmojiEntry('😂', 'risa llorar carcajada'),
      const _EmojiEntry('🙂', 'sonrisa leve'),
      const _EmojiEntry('🙃', 'sonrisa al reves'),
      const _EmojiEntry('😉', 'guino coqueto'),
      const _EmojiEntry('😊', 'sonrisa timido'),
      const _EmojiEntry('😇', 'angel inocente'),
      const _EmojiEntry('🥰', 'amor enamorado corazones'),
      const _EmojiEntry('😍', 'enamorado ojos corazon'),
      const _EmojiEntry('🤩', 'estrellas sorprendido genial'),
      const _EmojiEntry('😘', 'beso amor'),
      const _EmojiEntry('😗', 'beso'),
      const _EmojiEntry('😋', 'delicioso rico sabroso'),
      const _EmojiEntry('😛', 'lengua broma'),
      const _EmojiEntry('😜', 'lengua guino broma'),
      const _EmojiEntry('🤪', 'loco alocado broma'),
      const _EmojiEntry('😎', 'cool lentes genial'),
      const _EmojiEntry('🤓', 'nerd lentes'),
      const _EmojiEntry('🧐', 'monoculo curioso'),
      const _EmojiEntry('😏', 'picaro sonrisa'),
      const _EmojiEntry('😒', 'fastidio meh'),
      const _EmojiEntry('😞', 'triste decepcionado'),
      const _EmojiEntry('😔', 'triste pensativo'),
      const _EmojiEntry('😢', 'triste llorar'),
      const _EmojiEntry('😭', 'llorar mucho triste'),
      const _EmojiEntry('😤', 'enojado frustrado'),
      const _EmojiEntry('😠', 'enojado molesto'),
      const _EmojiEntry('😡', 'furioso enojado rojo'),
      const _EmojiEntry('🥺', 'ojitos suplica tierno'),
      const _EmojiEntry('😱', 'susto miedo grito'),
      const _EmojiEntry('😨', 'miedo asustado'),
      const _EmojiEntry('😰', 'nervioso ansioso sudor'),
      const _EmojiEntry('😴', 'dormido sueño'),
      const _EmojiEntry('🥱', 'bostezo cansado sueño'),
      const _EmojiEntry('🤔', 'pensando duda'),
      const _EmojiEntry('🤨', 'duda sospecha ceja'),
      const _EmojiEntry('😐', 'neutral sin expresion'),
      const _EmojiEntry('😑', 'neutral aburrido'),
      const _EmojiEntry('🙄', 'ojos en blanco fastidio'),
      const _EmojiEntry('😶', 'sin palabras'),
      const _EmojiEntry('🤯', 'mente explota sorpresa'),
      const _EmojiEntry('🥳', 'fiesta celebracion'),
      const _EmojiEntry('😷', 'enfermo cubrebocas'),
      const _EmojiEntry('🤒', 'enfermo fiebre'),
      const _EmojiEntry('🤕', 'lastimado herido'),
    ]),
    _EmojiCategory('Gestos', Icons.back_hand_outlined, [
      const _EmojiEntry('👍', 'pulgar arriba bien like'),
      const _EmojiEntry('👎', 'pulgar abajo mal dislike'),
      const _EmojiEntry('👌', 'ok perfecto'),
      const _EmojiEntry('✌️', 'paz victoria'),
      const _EmojiEntry('🤞', 'dedos cruzados suerte'),
      const _EmojiEntry('🤟', 'te amo mano'),
      const _EmojiEntry('🤘', 'rock mano'),
      const _EmojiEntry('👋', 'saludo hola adios'),
      const _EmojiEntry('🤙', 'llamame mano'),
      const _EmojiEntry('💪', 'musculo fuerza'),
      const _EmojiEntry('🙏', 'gracias por favor rezar'),
      const _EmojiEntry('👏', 'aplauso felicidades'),
      const _EmojiEntry('🙌', 'celebracion manos arriba'),
      const _EmojiEntry('🤝', 'trato apreton de manos'),
      const _EmojiEntry('✍️', 'escribir mano'),
      const _EmojiEntry('👉', 'apuntar derecha'),
      const _EmojiEntry('👈', 'apuntar izquierda'),
      const _EmojiEntry('👆', 'apuntar arriba'),
      const _EmojiEntry('👇', 'apuntar abajo'),
      const _EmojiEntry('☝️', 'apuntar arriba un dedo'),
      const _EmojiEntry('✊', 'puño fuerza'),
      const _EmojiEntry('👊', 'puño choca'),
    ]),
    _EmojiCategory('Corazones', Icons.favorite_border, [
      const _EmojiEntry('❤️', 'corazon amor rojo'),
      const _EmojiEntry('🧡', 'corazon naranja amor'),
      const _EmojiEntry('💛', 'corazon amarillo amor'),
      const _EmojiEntry('💚', 'corazon verde amor'),
      const _EmojiEntry('💙', 'corazon azul amor'),
      const _EmojiEntry('💜', 'corazon morado amor'),
      const _EmojiEntry('🖤', 'corazon negro amor'),
      const _EmojiEntry('🤍', 'corazon blanco amor'),
      const _EmojiEntry('🤎', 'corazon cafe amor'),
      const _EmojiEntry('💔', 'corazon roto triste'),
      const _EmojiEntry('❣️', 'corazon exclamacion amor'),
      const _EmojiEntry('💕', 'corazones amor cariño'),
      const _EmojiEntry('💞', 'corazones girando amor'),
      const _EmojiEntry('💓', 'corazon latiendo amor'),
      const _EmojiEntry('💗', 'corazon creciendo amor'),
      const _EmojiEntry('💖', 'corazon brillante amor'),
      const _EmojiEntry('💘', 'corazon flecha cupido'),
      const _EmojiEntry('💝', 'corazon regalo amor'),
    ]),
    _EmojiCategory('Animales', Icons.pets_outlined, [
      const _EmojiEntry('🐶', 'perro mascota'),
      const _EmojiEntry('🐱', 'gato mascota'),
      const _EmojiEntry('🐭', 'raton'),
      const _EmojiEntry('🐹', 'hamster'),
      const _EmojiEntry('🐰', 'conejo'),
      const _EmojiEntry('🦊', 'zorro'),
      const _EmojiEntry('🐻', 'oso'),
      const _EmojiEntry('🐼', 'panda'),
      const _EmojiEntry('🐨', 'koala'),
      const _EmojiEntry('🐯', 'tigre'),
      const _EmojiEntry('🦁', 'leon'),
      const _EmojiEntry('🐮', 'vaca'),
      const _EmojiEntry('🐷', 'cerdo'),
      const _EmojiEntry('🐸', 'rana'),
      const _EmojiEntry('🐵', 'mono'),
      const _EmojiEntry('🐔', 'gallina pollo'),
      const _EmojiEntry('🐧', 'pinguino'),
      const _EmojiEntry('🐦', 'pajaro ave'),
      const _EmojiEntry('🦄', 'unicornio'),
      const _EmojiEntry('🐝', 'abeja'),
      const _EmojiEntry('🐢', 'tortuga'),
      const _EmojiEntry('🐍', 'serpiente'),
      const _EmojiEntry('🐳', 'ballena'),
      const _EmojiEntry('🐬', 'delfin'),
      const _EmojiEntry('🐙', 'pulpo'),
      const _EmojiEntry('🦋', 'mariposa'),
    ]),
    _EmojiCategory('Comida', Icons.restaurant_outlined, [
      const _EmojiEntry('🍎', 'manzana fruta'),
      const _EmojiEntry('🍌', 'platano fruta'),
      const _EmojiEntry('🍉', 'sandia fruta'),
      const _EmojiEntry('🍇', 'uvas fruta'),
      const _EmojiEntry('🍓', 'fresa fruta'),
      const _EmojiEntry('🍕', 'pizza'),
      const _EmojiEntry('🍔', 'hamburguesa'),
      const _EmojiEntry('🍟', 'papas fritas'),
      const _EmojiEntry('🌭', 'hot dog'),
      const _EmojiEntry('🌮', 'taco'),
      const _EmojiEntry('🌯', 'burrito'),
      const _EmojiEntry('🍝', 'pasta espagueti'),
      const _EmojiEntry('🍣', 'sushi'),
      const _EmojiEntry('🍦', 'helado'),
      const _EmojiEntry('🍰', 'pastel torta'),
      const _EmojiEntry('🎂', 'pastel cumpleaños torta'),
      const _EmojiEntry('🍫', 'chocolate'),
      const _EmojiEntry('🍩', 'dona'),
      const _EmojiEntry('🍪', 'galleta'),
      const _EmojiEntry('☕', 'cafe'),
      const _EmojiEntry('🍺', 'cerveza'),
      const _EmojiEntry('🍷', 'vino'),
      const _EmojiEntry('🥤', 'refresco bebida'),
    ]),
    _EmojiCategory('Actividades', Icons.sports_soccer_outlined, [
      const _EmojiEntry('⚽', 'futbol balon'),
      const _EmojiEntry('🏀', 'basquetbol baloncesto'),
      const _EmojiEntry('🏈', 'futbol americano'),
      const _EmojiEntry('⚾', 'beisbol'),
      const _EmojiEntry('🎾', 'tenis'),
      const _EmojiEntry('🏐', 'voleibol'),
      const _EmojiEntry('🎮', 'videojuegos control'),
      const _EmojiEntry('🎲', 'dado juego'),
      const _EmojiEntry('🎯', 'diana objetivo'),
      const _EmojiEntry('🎸', 'guitarra musica'),
      const _EmojiEntry('🎧', 'audifonos musica'),
      const _EmojiEntry('🎤', 'microfono cantar'),
      const _EmojiEntry('🎨', 'arte pintura'),
      const _EmojiEntry('🎬', 'cine pelicula'),
      const _EmojiEntry('🏆', 'trofeo ganador'),
      const _EmojiEntry('🥇', 'medalla oro ganador'),
      const _EmojiEntry('🎉', 'fiesta celebracion confeti'),
      const _EmojiEntry('🎊', 'fiesta confeti celebracion'),
      const _EmojiEntry('🎁', 'regalo'),
    ]),
    _EmojiCategory('Viajes', Icons.flight_outlined, [
      const _EmojiEntry('🚗', 'carro auto coche'),
      const _EmojiEntry('🚕', 'taxi'),
      const _EmojiEntry('🚌', 'autobus camion'),
      const _EmojiEntry('🚲', 'bicicleta'),
      const _EmojiEntry('🏍️', 'moto motocicleta'),
      const _EmojiEntry('✈️', 'avion viaje'),
      const _EmojiEntry('🚀', 'cohete nave'),
      const _EmojiEntry('🚢', 'barco'),
      const _EmojiEntry('🚆', 'tren'),
      const _EmojiEntry('🗺️', 'mapa viaje'),
      const _EmojiEntry('🏖️', 'playa vacaciones'),
      const _EmojiEntry('🏝️', 'isla playa'),
      const _EmojiEntry('🏔️', 'montaña'),
      const _EmojiEntry('🗽', 'estatua libertad'),
      const _EmojiEntry('🏠', 'casa hogar'),
      const _EmojiEntry('🏢', 'edificio oficina'),
      const _EmojiEntry('🌆', 'ciudad atardecer'),
      const _EmojiEntry('🌃', 'ciudad noche'),
    ]),
    _EmojiCategory('Objetos', Icons.lightbulb_outline, [
      const _EmojiEntry('💡', 'idea bombilla foco'),
      const _EmojiEntry('📱', 'celular telefono'),
      const _EmojiEntry('💻', 'computadora laptop'),
      const _EmojiEntry('⌚', 'reloj'),
      const _EmojiEntry('📷', 'camara foto'),
      const _EmojiEntry('🎥', 'video camara'),
      const _EmojiEntry('📚', 'libros'),
      const _EmojiEntry('📝', 'nota apunte lapiz'),
      const _EmojiEntry('✏️', 'lapiz'),
      const _EmojiEntry('📌', 'chincheta pin'),
      const _EmojiEntry('📎', 'clip'),
      const _EmojiEntry('🔒', 'candado cerrado'),
      const _EmojiEntry('🔑', 'llave'),
      const _EmojiEntry('🔨', 'martillo herramienta'),
      const _EmojiEntry('⚙️', 'engranaje configuracion'),
      const _EmojiEntry('💰', 'dinero bolsa'),
      const _EmojiEntry('💵', 'dinero billete'),
      const _EmojiEntry('🎓', 'graduacion birrete'),
      const _EmojiEntry('📅', 'calendario fecha'),
      const _EmojiEntry('⏰', 'alarma reloj despertador'),
    ]),
    _EmojiCategory('Símbolos', Icons.tag_outlined, [
      const _EmojiEntry('🔥', 'fuego genial'),
      const _EmojiEntry('✨', 'brillos destellos'),
      const _EmojiEntry('⭐', 'estrella'),
      const _EmojiEntry('🌟', 'estrella brillante'),
      const _EmojiEntry('💯', 'cien puntos perfecto'),
      const _EmojiEntry('✅', 'check listo correcto'),
      const _EmojiEntry('❌', 'equis mal incorrecto'),
      const _EmojiEntry('❓', 'pregunta duda'),
      const _EmojiEntry('❗', 'exclamacion importante'),
      const _EmojiEntry('⚠️', 'advertencia alerta'),
      const _EmojiEntry('♻️', 'reciclar'),
      const _EmojiEntry('🔄', 'recargar actualizar'),
      const _EmojiEntry('🔔', 'campana notificacion'),
      const _EmojiEntry('💤', 'dormir zzz'),
      const _EmojiEntry('💬', 'globo de dialogo chat'),
      const _EmojiEntry('💭', 'pensamiento globo'),
      const _EmojiEntry('🚫', 'prohibido no'),
      const _EmojiEntry('🆗', 'ok listo'),
    ]),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<_EmojiEntry> get _searchResults {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return _categories
        .expand((c) => c.entries)
        .where((e) => e.keywords.contains(q) || e.char == q)
        .toList();
  }

  Widget _grid(List<_EmojiEntry> entries) {
    if (entries.isEmpty) {
      return Center(
        child: Text(
          'Sin resultados',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 8,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: () => widget.onEmojiSelected(entry.char),
          child: Center(
            child: Text(entry.char, style: const TextStyle(fontSize: 22)),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final searching = _query.trim().isNotEmpty;

    return Container(
      height: EmojiPickerPanel.height,
      decoration: BoxDecoration(
        color: AppColors.bgBase,
        border: Border(top: BorderSide(color: AppColors.surfaceBorder)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, size: 18, color: AppColors.textMuted),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _query = v),
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        hintText: 'Buscar emoji…',
                        hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                      ),
                    ),
                  ),
                  if (searching)
                    InkWell(
                      onTap: () => setState(() {
                        _query = '';
                        _searchController.clear();
                      }),
                      child: Icon(Icons.close, size: 16, color: AppColors.textMuted),
                    ),
                ],
              ),
            ),
          ),
          if (!searching)
            TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: AppColors.accent,
              labelColor: AppColors.accent,
              unselectedLabelColor: AppColors.textMuted,
              tabs: [
                for (final c in _categories)
                  Tab(icon: Icon(c.icon, size: 18), text: c.label),
              ],
            ),
          Expanded(
            child: searching
                ? _grid(_searchResults)
                : TabBarView(
                    controller: _tabController,
                    children: [for (final c in _categories) _grid(c.entries)],
                  ),
          ),
        ],
      ),
    );
  }
}

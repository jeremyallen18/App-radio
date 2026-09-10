<?php
// Filtro de moderación para la caja de "Comentarios en vivo" (hero de Inicio).
// Frena spam, enlaces, lenguaje ofensivo y contenido de riesgo ANTES de que
// un comentario toque la BD. Lo usa inc/data/live_comments.php.
//
// Ningún filtro de palabras es perfecto (problema "Scunthorpe": "disputa"
// contiene "puta", "Maricarmen" contiene "marica", "análisis" contiene "anal").
// Por eso el filtro trabaja en NIVELES, cada uno con su forma de comparar:
//
//   ENMASCARAR (el comentario se publica con la palabra tachada ****):
//   - MOD_PROFANITY        -> token suelto; términos >=4 también por prefijo y
//                             >=5 por subcadena, para atrapar "putamadre".
//   - MOD_PROFANITY_EXACT  -> SOLO token idéntico ("pene", nunca "penetración").
//
//   RECHAZAR (el comentario NO se publica; contenido +18, odio, amenazas):
//   - MOD_BANNED           -> subcadena letra-a-letra ("p.o.r.n" -> "porn").
//                             Lista muy corta: solo lo que jamás aparece dentro
//                             de una palabra legítima.
//   - MOD_BANNED_TOKENS    -> token completo; términos >=8 también por prefijo
//                             ("violador" -> "violadores") y >=10 por subcadena.
//                             Aquí va el grueso del vocabulario +18/insultos
//                             graves, porque el match por token NO pisa nombres
//                             ni palabras comunes.
//   - MOD_BANNED_PHRASES   -> frase completa, palabra por palabra, con
//                             separadores flexibles ("se.la.come", "se-la-come").
//
// Un Nombre que ES o CONTIENE un término de nivel RECHAZAR se bloquea igual que
// el comentario (es troleo con el campo Nombre). Ajusta las listas con lo que
// se vea en producción -- están pensadas para español de México / Latinoamérica
// y algo de inglés.

// Rechazo por SUBCADENA. Mantener MUY corto: solo términos que no viven dentro
// de ninguna palabra legítima en español ni inglés.
const MOD_BANNED = [
    'chingada', 'chingado', 'chingar', 'chinga tu', 'chingadera',
    'chingatumadre', 'malparido', 'hijueputa', 'hijodeputa', 'jijueputa',
    'conchetumadre', 'conchesumadre',
    'nigger', 'nigga', 'faggot',
    'kill yourself', 'pornhub', 'onlyfans', 'xvideos', 'xhamster', 'xnxx',
    'redtube', 'youporn', 'brazzers', 'spankbang', 'stripchat',
    'child porn', 'childporn', 'pornoinfantil', 'cp gratis',
];

// Rechazo por TOKEN completo (palabra suelta). Es la lista "masiva": no pisa
// nombres propios ni palabras de uso diario porque exige la palabra entera.
// Términos >=8 letras también matchean por prefijo (plurales / conjugaciones);
// >=10 por subcadena (concatenaciones tipo "chupaverga").
const MOD_BANNED_TOKENS = [
    // --- Actos sexuales explícitos (ES) ---
    'follar', 'follame', 'follando', 'follada', 'follaste',
    'culear', 'culeando', 'culeo', 'culiar', 'culiando',
    'garchar', 'garchame', 'garchando', 'garchen',
    'singar', 'singando', 'singao',
    'verguear', 'vergueando', 'verguearte',
    'cogerte', 'cogerme', 'cogernos', 'cojerte', 'cojerme',
    'chupamela', 'chupensela', 'chupaverga', 'chupavergas', 'chupapito',
    'chupapitos', 'chupapenes', 'chupasela',
    'mamamela', 'mamensela', 'mamaverga', 'mamavergas', 'mamapito',
    'mamapenes', 'mamasela', 'mamahuevo', 'mamahuevos',
    'comeverga', 'comevergas', 'comepito', 'comepenes',
    'masturbar', 'masturbarse', 'masturbate', 'masturbacion', 'masturbandose',
    'masturbando',
    'orgasmo', 'orgasmos', 'orgasmico',
    'eyacular', 'eyaculacion', 'eyaculando',
    'sexoanal', 'sexooral', 'sexoexplicito',
    'violador', 'violadora', 'follador', 'folladora',
    // --- Pornografía / términos +18 (ES + EN) ---
    'porno', 'porn', 'pornografia', 'pornografico', 'pornografica',
    'pornostar', 'pornstar', 'pornazo', 'nopor', 'rule34',
    'hentai', 'hentais', 'gangbang', 'bukkake', 'creampie', 'blowjob',
    'handjob', 'rimjob', 'deepthroat', 'cumshot', 'facefuck', 'titfuck',
    'squirt', 'camwhore', 'sexcam', 'sexchat', 'sexdate', 'milf', 'gilf',
    // --- Prostitución ---
    'prostituta', 'prostituto', 'prostitucion', 'prostibulo', 'prostibulos',
    'burdel', 'burdeles', 'piruja', 'pirujas',
    'ramera', 'rameras', 'meretriz', 'fichera', 'sexoservidora',
    'sexoservidor', 'sexoservicio',
    // --- Menores / contenido ilegal ---
    'pedofilo', 'pedofilos', 'pedofila', 'pedofilia', 'pederasta',
    'pederastas', 'pederastia', 'lolicon', 'shotacon', 'jailbait',
    'zoofilia', 'zoofilico', 'bestialismo', 'bestialidad', 'incesto',
    'incestuoso', 'incestuosa',
    // --- Insultos / expresiones graves de "muérete" en una palabra ---
    'matense', 'mueranse', 'suicidense', 'ahorcate', 'ahorquense',
    'degollate',
    // --- Insultos discriminatorios (odio) ---
    'sudaca', 'sudacas', 'sudaka', 'negrata', 'negratas', 'sidoso', 'sidosos',
    'sidosa', 'sidosas', 'mongolico', 'mongolicos', 'mongolica',
    'mongoloide', 'subnormal', 'subnormales', 'retrasadomental',
    'maricon', 'maricones', 'mariconazo', 'marica', 'maricas',
    'retard', 'retards', 'retarded', 'faggots',
    'spic', 'spics', 'wetback', 'wetbacks', 'beaner', 'chink',
    'chinks', 'gook', 'tranny', 'trannies', 'shemale', 'ladyboy', 'travelo',
    // --- Doble sentido en UNA palabra (imperativos) ---
    'chupala', 'chupalo', 'chupamelo', 'mamala', 'mamalo', 'mamamelo',
    'jalatela', 'jalensela',
];

// Chistes/piropos de doble sentido armados con puras palabras comunes ("se",
// "la", "come"): no hay forma de "detectar doble sentido" en general sin
// ahogarse en falsos positivos, así que esto es una lista curada de FRASES
// completas conocidas -- se va ampliando con lo que aparezca en producción.
// Van APARTE de MOD_BANNED (que compara pegando todo sin espacios) porque
// esa técnica, con frases hechas solo de palabras de uso diario, atrapa
// coincidencias por accidente ("se la come" -> "selacome" es substring de
// "selaCOMENta"): mod_contains_banned_phrase() exige palabra completa con
// separadores flexibles entre cada palabra, nunca a mitad de otra.
const MOD_BANNED_PHRASES = [
    // Doble sentido / sexual
    'se la come', 'se lo come', 'me la comes', 'te la como',
    'se la chupa', 'se lo chupa', 'me la chupas', 'te la chupo', 'chupame la',
    'chupame el', 'chupance la', 'chupenme la',
    'se la mama', 'se lo mama', 'me la mamas', 'te la mamo', 'mamame la',
    'mamame el', 'mama verga', 'mamar verga',
    'parte de mi cola', 'quieres ser mi cola',
    'te la meto', 'te lo meto', 'te voy a meter',
    'abre las piernas', 'ponte en cuatro', 'ponte de nalgas', 'en cuatro patas',
    'te cojo', 'te voy a coger', 'quiero cogerte', 'te quiero coger',
    'te gusta la verga', 'te gusta el pito', 'chupas verga', 'comes verga',
    'te la jalas', 'hazte una chaqueta', 'hacerse una chaqueta',
    'hazte la paja', 'hacerse la paja',
    'sexo anal', 'sexo oral', 'sexo explicito', 'sexo duro', 'sexo casual',
    'hacer un trio', 'foto de tu pack',
    'manda nudes', 'manda pack', 'pasame nudes', 'manda fotos desnuda',
    'ensena las tetas', 'saca las tetas', 'foto de tus tetas',
    // Amenazas / autolesión
    'te voy a matar', 'te voy a violar', 'te voy a golpear',
    'te voy a partir la madre', 'te parto la cara', 'te rompo la cara',
    'te voy a reventar', 'te voy a romper', 'voy a matar a',
    'ojala te mueras', 'ojala te maten', 'ojala te violen',
    'deberias morirte', 'deberias matarte', 'deberias suicidarte',
    'porque no te matas', 'mejor matate', 'matate ya',
    'pegate un tiro', 'pegate un balazo', 'tirate de un puente',
    'cortate las venas', 'tomate un cloro',
    // Odio
    'negro de mierda', 'india de mierda', 'indio de mierda',
    'judio de mierda', 'sudaca de mierda', 'puto negro', 'pinche indio',
    'pinche negro', 'muerte a los', 'hitler tenia razon', 'heil hitler',
    'sieg heil', 'regresate a tu pais', 'vuelvete a tu pais',
];

// Groserías que por sí solas son inequívocas pero que, comparadas como
// prefijo o subcadena, pisarían palabras legítimas ("pene" -> "penetración",
// "cock" -> "cocktail", "culo" -> "calculo"). Se comparan SOLO como token
// idéntico. Además, un nombre que sea exactamente uno de estos términos (o de
// MOD_PROFANITY) hace que se rechace el comentario (troleo con el Nombre).
const MOD_PROFANITY_EXACT = [
    'pene', 'penes', 'verguita', 'pipi', 'nalga', 'nalgas', 'nalgon',
    'nalgona', 'nalgotas', 'culo', 'culos', 'culito', 'culitos', 'culote',
    'tetas', 'tetona', 'tetonas', 'chichis', 'bubis', 'poronga', 'porongas',
    'cock', 'cocks', 'boner', 'boners', 'wank', 'jizz',
];

// Se enmascara con asteriscos y el comentario se publica igual. Términos de
// 4+ letras también matchean por prefijo y de 5+ por subcadena, así que sus
// derivados ("putazo", "cabronazo", "fucking") caen solos.
const MOD_PROFANITY = [
    // Español (México / Latinoamérica)
    'puta', 'puto', 'putona', 'putiza', 'putazo', 'putos', 'putas',
    'pendejo', 'pendeja', 'pendejadas', 'pendejada', 'apendejado',
    'cabron', 'cabrona', 'cabrones', 'cabronazo',
    'verga', 'vergas', 'vergero', 'mierda', 'mierdas', 'mierdero',
    'joto', 'jotos', 'jotito', 'zorra', 'zorras', 'zorron', 'zorrona',
    'imbecil', 'imbeciles', 'estupido', 'estupida', 'estupidez', 'idiota',
    'idiotas', 'idiotez', 'gilipollas', 'gilipollez',
    'mamada', 'mamadas', 'mamador', 'mamadora', 'mamon', 'mamona', 'mamones',
    'culero', 'culera', 'culeros', 'culeando', 'culiao', 'culiado',
    'naco', 'naca', 'nacos', 'nacas', 'jodete', 'jodido', 'jodida',
    'jodanse', 'joder', 'chingao', 'chingadazo',
    'pinche', 'pinches', 'pinchi',
    'carajo', 'carajos', 'cagada', 'cagadas', 'cagar', 'cagando', 'cagon',
    'cagaste', 'cagalera', 'encabronado', 'encabronada',
    'ojete', 'ojetes', 'cojones', 'cojudo', 'cojuda', 'huevon', 'hueon',
    'weon', 'weona', 'pelotudo', 'pelotuda', 'pelotudos',
    'sorete', 'soretes', 'boludo', 'boluda', 'gonorrea',
    'malnacido', 'malnacida', 'desgraciado',
    'putivuelta', 'putero', 'puteria', 'guarra', 'guarro', 'zopenco',
    'baboso', 'babosa', 'tarado', 'tarada',
    'verguiza', 'madriza',
    // Inglés
    'fuck', 'fucker', 'fucking', 'motherfucker', 'motherfuckers', 'mothafucka',
    'shit', 'bullshit', 'horseshit', 'batshit', 'bitch', 'bitches',
    'asshole', 'assholes', 'dumbass', 'jackass', 'dick', 'dickhead',
    'cunt', 'bastard', 'slut', 'sluts', 'whore', 'whores', 'douche',
    'douchebag', 'wanker', 'bollocks', 'twat', 'pussy',
];

// Minúsculas, sin acentos, sin "leet", sin repeticiones largas de una letra.
function mod_normalize(string $s): string {
    $s = mb_strtolower($s, 'UTF-8');
    $s = strtr($s, [
        'á' => 'a', 'à' => 'a', 'ä' => 'a', 'â' => 'a', 'ã' => 'a',
        'é' => 'e', 'è' => 'e', 'ë' => 'e', 'ê' => 'e',
        'í' => 'i', 'ì' => 'i', 'ï' => 'i', 'î' => 'i',
        'ó' => 'o', 'ò' => 'o', 'ö' => 'o', 'ô' => 'o', 'õ' => 'o',
        'ú' => 'u', 'ù' => 'u', 'ü' => 'u', 'û' => 'u',
        'ñ' => 'n', 'ç' => 'c',
    ]);
    $s = strtr($s, ['0' => 'o', '1' => 'i', '3' => 'e', '4' => 'a', '5' => 's', '7' => 't', '@' => 'a', '$' => 's', '8' => 'b']);
    return preg_replace('/(.)\1{2,}/u', '$1', $s);
}

// Deja solo letras a-z (para comparar términos "graves" ignorando espacios,
// puntos o guiones intercalados: "p.o.r.n.h.u.b" -> "pornhub").
function mod_letters_only(string $s): string {
    return preg_replace('/[^a-z]/', '', mod_normalize($s));
}

// Limpieza estructural: quita HTML, caracteres de control e "invisibles"
// (zero-width, marcas de dirección RTL usadas para ofuscar/romper el layout).
//
// OJO: antes esto llamaba a strip_tags() antes de quitar "<"/">" a mano.
// strip_tags() trata cualquier "<" sin un ">" que lo cierre despues como el
// inicio de una etiqueta sin terminar y se come TODO lo que sigue hasta el
// final de la cadena (comportamiento documentado de PHP) -- un comentario
// con un simple "<" suelto (una comparacion "i<10" de un pedazo de codigo,
// un emoticon "<3" mal cerrado, etc.) quedaba truncado en ese punto, y con
// el resto del texto ya borrado, cualquier filtro posterior (groserias,
// deteccion de codigo) dejaba de ver lo que faltaba. Quitar "<"/">" a mano
// primero ya es suficiente para que no pueda sobrevivir ninguna etiqueta
// HTML (le hace falta un "<...>" completo), sin ese efecto secundario.
function mod_sanitize_text(string $s): string {
    $s = str_replace(['<', '>'], '', $s);
    $s = preg_replace('/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/u', '', $s);
    $s = preg_replace('/[\x{200B}-\x{200F}\x{202A}-\x{202E}\x{2060}-\x{2064}\x{2066}-\x{2069}\x{FEFF}]/u', '', $s);
    return trim(preg_replace('/\s+/u', ' ', $s));
}

// Busca las frases de MOD_BANNED_PHRASES como palabras completas separadas
// por espacio/punto/guión (para pillar "se.la.come" o "se-la-come"), nunca a
// mitad de otra palabra ("\b" al final evita que "come" case dentro de
// "comenta", "comen", etc.). Recibe el texto ya normalizado (mod_normalize:
// minúsculas, sin acentos, sin leet) pero CON los espacios originales.
function mod_contains_banned_phrase(string $normalizedText): bool {
    foreach (MOD_BANNED_PHRASES as $phrase) {
        $words = array_map(
            static fn(string $w): string => preg_quote($w, '/'),
            explode(' ', $phrase)
        );
        if (preg_match('/\b' . implode('[\s._-]+', $words) . '\b/', $normalizedText)) {
            return true;
        }
    }
    return false;
}

// Recorre los tokens (palabras sueltas) de un texto YA normalizado
// (mod_normalize) y devuelve el primer término de MOD_BANNED_TOKENS que
// aparece, o null. Compara token contra término:
//   - idéntico                          -> siempre
//   - término >= 8 letras, como prefijo -> "violador" atrapa "violadores"
//   - término >= 10 letras, como subcadena -> "chupaverga" dentro de un token
//     pegado ("comechupavergas")
// Nunca matchea a mitad de una palabra corriente: por eso "marica" (6) NO
// dispara dentro de "Maricarmen" y "retard" (6) NO dispara en "retardado".
function mod_find_banned_token(string $normalizedText): ?string {
    if (!preg_match_all("/\p{L}[\p{L}']*/u", $normalizedText, $mm)) {
        return null;
    }
    foreach ($mm[0] as $token) {
        $norm = preg_replace('/[^a-z]/', '', $token);
        if ($norm === '' || mb_strlen($norm) < 4) {
            continue;
        }
        foreach (MOD_BANNED_TOKENS as $term) {
            $t = preg_replace('/[^a-z]/', '', mod_normalize($term));
            if ($t === '') {
                continue;
            }
            if ($norm === $t
                || (mb_strlen($t) >= 8 && strpos($norm, $t) === 0)
                || (mb_strlen($t) >= 10 && strpos($norm, $t) !== false)
            ) {
                return $term;
            }
        }
    }
    return null;
}

// Censura la palabra completa: "puta" -> "****" (se mantiene el largo para
// que se lea como texto tachado, no como si faltara una palabra).
function mod_mask_word(string $word): string {
    return str_repeat('*', mb_strlen($word));
}

// Palabras clave de programación que casi nunca aparecen sueltas en una
// conversación normal (varios idiomas/lenguajes a la vez: PHP, JS, Python,
// SQL, Java/C#, C/C++, shell). Se buscan como palabra completa sobre el
// texto YA normalizado (sin acentos/leet), así que "3cho" también cae en
// "echo". Deliberadamente no incluye palabras que sí son de uso común en
// español ("clase", "función", "importar"...), solo las que casi siempre
// delatan código copiado y pegado.
const MOD_CODE_KEYWORDS = [
    'function', 'const', 'var', 'let', 'return', 'echo', 'print', 'printf',
    'console', 'require', 'import', 'export', 'class', 'public', 'private',
    'static', 'void', 'null', 'undefined', 'true', 'false', 'foreach',
    'while', 'endforeach', 'endif', 'elseif', 'lambda', 'def', 'self',
    'this', 'new', 'delete', 'catch', 'throw', 'try', 'async', 'await',
    'select', 'insert', 'update', 'delete', 'drop', 'table', 'database',
    'union', 'where', 'values', 'from', 'into', 'set', 'alert', 'eval', 'script', 'document',
    'window', 'fetch', 'json', 'namespace', 'include', 'package', 'struct',
    'enum', 'interface', 'extends', 'implements', 'override',
];

// Heurística "esto parece código, no un comentario" para cualquier lenguaje:
// no hay forma de detectar código con 100% de certeza, así que se suma
// evidencia (palabras clave de programación + símbolos que casi nunca salen
// juntos en una frase normal) y se rechaza solo si el total pasa un umbral,
// para no atrapar a alguien que por casualidad usa una palabra suelta como
// "static" o pone un signo de "->" haciendo un dibujito.
function mod_looks_like_code(string $body): bool {
    $score = 0;

    $normalized = mod_normalize($body);
    foreach (MOD_CODE_KEYWORDS as $word) {
        if (preg_match('/\b' . preg_quote($word, '/') . '\b/', $normalized)) {
            $score += 2;
        }
    }

    // Llaves emparejadas tipo bloque de código: function() { ... }
    if (preg_match('/\{[^{}]*\}/u', $body)) {
        $score += 2;
    }
    // Punto y coma: casi nadie termina una frase normal en español con ";".
    if (substr_count($body, ';') >= 2) {
        $score += 2;
    }
    // Llamada a función: nombre(argumentos)
    if (preg_match('/\b[a-z_][a-z0-9_]{1,}\s*\([^()]*\)/i', $body)) {
        $score += 1;
    }
    // Operadores/sintaxis que casi no aparecen en prosa: =>, ->, ::, ==, !=, &&, ||, <=, >=
    if (preg_match('/=>|->|::|==|!=|&&|\|\||<=|>=/', $body)) {
        $score += 2;
    }
    // Comentarios de código: //, /* */, --
    if (preg_match('#//\S|/\*.*\*/#u', $body) || preg_match('/(?:^|\s)--\s/', $body)) {
        $score += 1;
    }
    // Asignación tipo variable = valor, repetida (una sola no basta: "x = 5"
    // podría ser una operación matemática escrita a mano).
    if (preg_match_all('/\b[a-z_][a-z0-9_]*\s*=\s*[^=]/i', $body) >= 2) {
        $score += 2;
    }
    return $score >= 4;
}

// Aplica el filtro a un comentario ya limpio (mod_sanitize_text).
// Devuelve ['name' => ..., 'body' => ...] con la grosería enmascarada, o
// lanza InvalidArgumentException si el contenido no se puede publicar.
function mod_filter_comment(string $name, string $body): array {
    // Marcadores de apertura de código (<?php, <?=, <script>, un shebang
    // #!/bin/...) se revisan ANTES de sanitizar: mod_sanitize_text() quita
    // "<"/">" a proposito (evita HTML/XSS), pero eso mismo desarma la firma
    // "<?php" dejandola como "?php" -- ya no la reconoceria nadie despues.
    $rawBodyHadCodeOpener = (bool) preg_match('/<\?php|<\?=|<script\b|^\s*#!\//i', $body)
        // Sentencias SQL completas: se detectan aparte y de forma directa
        // (no solo sumando puntos por palabra suelta) porque "SELECT ...
        // FROM ..." es casi 100% inequivoco y nunca deberia depender de si
        // el resto del mensaje trae o no otras señales de código.
        || (bool) preg_match(
            '/\bselect\b.{0,80}?\bfrom\b|\binsert\s+into\b|\bupdate\b.{0,40}?\bset\b|\bdelete\s+from\b|\bdrop\s+(table|database)\b|\bunion\s+select\b|\bcreate\s+(table|database)\b|\balter\s+table\b/is',
            $body
        );

    $name = mod_sanitize_text($name);
    $body = mod_sanitize_text($body);

    if ($body === '') {
        throw new InvalidArgumentException('El comentario está vacío.');
    }

    $normalizedBody = mod_normalize($body);
    $lettersBody = mod_letters_only($body);

    // 1. Términos prohibidos en el COMENTARIO (rechazo total): +18 explícito,
    // odio, amenazas. Tres formas de comparar, de la más estricta a la más
    // tolerante -- ver el bloque de constantes arriba.
    foreach (MOD_BANNED as $term) {
        $t = preg_replace('/[^a-z]/', '', mod_normalize($term));
        if ($t !== '' && strpos($lettersBody, $t) !== false) {
            throw new InvalidArgumentException('Tu comentario no cumple las normas de la comunidad.');
        }
    }
    if (mod_find_banned_token($normalizedBody) !== null) {
        throw new InvalidArgumentException('Tu comentario no cumple las normas de la comunidad.');
    }
    if (mod_contains_banned_phrase($normalizedBody)) {
        throw new InvalidArgumentException('Tu comentario no cumple las normas de la comunidad.');
    }

    $normalizedName = mod_normalize($name);
    $lettersName = mod_letters_only($name);

    // Un nombre que ES, él solo, una grosería o término prohibido ("PENE",
    // "puto", "maricón", "verguita"): eso no es un oyente que se pasó de la
    // raya en el mensaje, es troleo puro usando el campo Nombre -> se RECHAZA
    // el comentario completo, no se publica.
    foreach (array_merge(MOD_BANNED, MOD_PROFANITY, MOD_PROFANITY_EXACT) as $term) {
        $t = preg_replace('/[^a-z]/', '', mod_normalize($term));
        if ($t !== '' && $lettersName === $t) {
            throw new InvalidArgumentException('Elige otro nombre para poder comentar.');
        }
    }

    // Un nombre que CONTIENE contenido de nivel "rechazar" (+18, odio,
    // amenazas) en cualquier parte: el Nombre es corto y visible, no hay
    // motivo legítimo para meter ahí esas palabras -> se bloquea igual que el
    // comentario. (Las groserías "suaves" en el nombre solo lo degradan a
    // "Oyente", más abajo.)
    foreach (MOD_BANNED as $term) {
        $t = preg_replace('/[^a-z]/', '', mod_normalize($term));
        if ($t !== '' && $lettersName !== '' && strpos($lettersName, $t) !== false) {
            throw new InvalidArgumentException('Elige otro nombre para poder comentar.');
        }
    }
    if (mod_find_banned_token($normalizedName) !== null
        || mod_contains_banned_phrase($normalizedName)) {
        throw new InvalidArgumentException('Elige otro nombre para poder comentar.');
    }

    // Un nombre que solo CONTIENE una grosería dentro de algo más ("el pinche
    // Juan"): se degrada a "Oyente", sin bloquear el comentario.
    foreach (array_merge(MOD_BANNED, MOD_PROFANITY) as $term) {
        $t = preg_replace('/[^a-z]/', '', mod_normalize($term));
        if ($t !== '' && $lettersName !== '' && strpos($lettersName, $t) !== false) {
            $name = 'Oyente';
            break;
        }
    }
    // Los términos de MOD_PROFANITY_EXACT (comparación solo por token completo,
    // para no pisar "Penélope" con "pene") también degradan un nombre de
    // varias palabras: "Pene Juan" -> "Oyente".
    foreach (preg_split('/\s+/u', mod_normalize($name), -1, PREG_SPLIT_NO_EMPTY) ?: [] as $namePart) {
        $partLetters = preg_replace('/[^a-z]/', '', $namePart);
        foreach (MOD_PROFANITY_EXACT as $term) {
            $t = preg_replace('/[^a-z]/', '', mod_normalize($term));
            if ($t !== '' && $partLetters === $t) {
                $name = 'Oyente';
                break 2;
            }
        }
    }
    // Un nombre que "parece código" (poco probable que sea legítimo): mismo
    // trato que un nombre con groserías, se reemplaza sin bloquear el envío.
    if ($name !== '' && mod_looks_like_code($name)) {
        $name = 'Oyente';
    }

    // 1.6 Evasión repartiendo la grosería entre Nombre y Comentario (ej.
    // Nombre "Mama" + Comentario "Dorita" -> junto se lee "mamadorita", muy
    // cerca de "mamadora"): cada campo por separado es inocente, así que
    // ningún chequeo de arriba lo agarra. Se compara la unión letra-por-
    // letra de los dos campos contra las mismas listas, y solo cuenta si el
    // término NO aparece ya en uno de los dos por separado (eso ya lo
    // bloquea/enmascara el resto del filtro). Se exige termino >= 5
    // caracteres -- por debajo de eso el riesgo de "media palabra de aquí +
    // media palabra de alla" coincidiendo por pura casualidad es demasiado
    // alto para justificar rechazar el comentario completo.
    if ($lettersName !== '' && $lettersBody !== '') {
        $lettersCombined = $lettersName . $lettersBody;
        foreach (array_merge(MOD_BANNED, MOD_BANNED_TOKENS, MOD_PROFANITY) as $term) {
            $t = preg_replace('/[^a-z]/', '', mod_normalize($term));
            if ($t === '' || mb_strlen($t) < 5) {
                continue;
            }
            if (strpos($lettersCombined, $t) !== false
                && strpos($lettersName, $t) === false
                && strpos($lettersBody, $t) === false
            ) {
                throw new InvalidArgumentException('Tu comentario no cumple las normas de la comunidad.');
            }
        }
        // Mismo caso pero con las FRASES de doble sentido (ej. Nombre "Sela"
        // + Comentario "chupa"): aquí sí se compara pegado sin espacios,
        // porque entre dos campos separados nunca hay un espacio real que
        // preservar -- el riesgo de "\bcomenta\b" del chequeo por palabra ya
        // no aplica igual, aunque queda el riesgo normal de Scunthorpe
        // (un nombre como "Marisela" + un comentario que empiece en "come"
        // también pegaría "selacome"; con nombres así de largo es poco
        // probable pero puede pasar).
        foreach (MOD_BANNED_PHRASES as $phrase) {
            $t = str_replace(' ', '', $phrase);
            if (strpos($lettersCombined, $t) !== false) {
                throw new InvalidArgumentException('Tu comentario no cumple las normas de la comunidad.');
            }
        }
    }

    // 1.5 Código pegado (cualquier lenguaje): se rechaza el comentario
    // completo, igual que los términos prohibidos -- esto es un chat en
    // vivo, no un lugar para pegar scripts.
    if ($rawBodyHadCodeOpener || mod_looks_like_code($body)) {
        throw new InvalidArgumentException('No se permite compartir código en los comentarios.');
    }

    // 2. Enlaces / datos de contacto (spam clásico).
    if (preg_match('#(https?://|www\.[a-z0-9]|\b[a-z0-9][a-z0-9-]*\.(com|net|org|mx|io|co|info|xyz|link|shop|online|site|ru|tk|biz|app|es)\b)#i', $body)) {
        throw new InvalidArgumentException('No se permiten enlaces en los comentarios.');
    }
    if (preg_match('/[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}/i', $body)) {
        throw new InvalidArgumentException('No compartas correos ni datos personales.');
    }
    if (preg_match('/(?:\d[\s.\-]?){9,}/', $body)) {
        throw new InvalidArgumentException('No compartas números de teléfono ni datos personales.');
    }

    // 3. Forma de spam: gritos, símbolos repetidos, una sola letra estirada.
    $letters = preg_replace('/[^\p{L}]/u', '', $body);
    $uppers = preg_replace('/[^\p{Lu}]/u', '', $body);
    if (mb_strlen($letters) >= 12 && mb_strlen($uppers) / mb_strlen($letters) > 0.7) {
        throw new InvalidArgumentException('Evita escribir todo en mayúsculas.');
    }
    if (preg_match('/(.)\1{7,}/u', $body)) {
        throw new InvalidArgumentException('Evita repetir el mismo carácter tantas veces.');
    }
    if (preg_match('/^(.{1,3})\1{5,}$/u', preg_replace('/\s+/u', '', $body))) {
        throw new InvalidArgumentException('Ese comentario parece spam.');
    }
    // Letras sueltas encadenadas ("p u t a", "h.o.l.a"): casi siempre es un
    // intento de esquivar el filtro escribiendo palabra por letra.
    if (preg_match('/(?:\b\p{L}\b[\s._\-]+){3,}\p{L}\b/u', $body)) {
        throw new InvalidArgumentException('Ese comentario parece spam.');
    }

    // 4. Groserías: enmascarar token a token.
    $masked = 0;
    $body = preg_replace_callback('/\p{L}[\p{L}\']*/u', static function (array $m) use (&$masked): string {
        $token = $m[0];
        $norm = preg_replace('/[^a-z]/', '', mod_normalize($token));
        if ($norm === '') {
            return $token;
        }
        // Términos de token completo ("pene" pero no "penetración").
        foreach (MOD_PROFANITY_EXACT as $term) {
            $t = preg_replace('/[^a-z]/', '', mod_normalize($term));
            if ($t !== '' && $norm === $t) {
                $masked++;
                return mod_mask_word($token);
            }
        }
        foreach (MOD_PROFANITY as $term) {
            $t = preg_replace('/[^a-z]/', '', mod_normalize($term));
            if ($t === '') {
                continue;
            }
            $hit = ($norm === $t)
                || (mb_strlen($t) >= 4 && strpos($norm, $t) === 0)
                || (mb_strlen($t) >= 5 && strpos($norm, $t) !== false);
            if ($hit) {
                $masked++;
                return mod_mask_word($token);
            }
        }
        return $token;
    }, $body);

    // 5. Si tras enmascarar casi no queda texto real, era puro insulto.
    if ($masked > 0) {
        $remaining = preg_replace('/[^\p{L}]/u', '', str_replace('*', '', $body));
        if (mb_strlen($remaining) < 2) {
            throw new InvalidArgumentException('Tu comentario no cumple las normas de la comunidad.');
        }
    }

    return ['name' => $name, 'body' => $body];
}

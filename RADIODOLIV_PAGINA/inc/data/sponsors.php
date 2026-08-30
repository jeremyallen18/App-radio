<?php
// Fuente de patrocinadores/aliados de la Sección Azul. Los datos viven ahora
// en la BD compartida (hive_db, tablas sponsors/sponsor_socials — ver
// config/migrations/2026_08_06_create_sponsors.sql). Si la consulta falla,
// se degrada al respaldo estático de get_sponsors_fallback() para que la
// página nunca se quede en blanco.
function get_sponsors(): array {
    try {
        require_once __DIR__ . '/../../config/db.php';
        $pdo = get_pdo();

        $sponsors = $pdo->query('
            SELECT id, name, category, category_label, icon, image, subtitle, summary, description, map
            FROM sponsors
            ORDER BY sort_order ASC, id ASC
        ')->fetchAll();

        if (!$sponsors) {
            return get_sponsors_fallback();
        }

        $socialsStmt = $pdo->query('
            SELECT sponsor_id, label, icon, url
            FROM sponsor_socials
            ORDER BY sponsor_id ASC, sort_order ASC
        ');
        $socialsBySponsor = [];
        foreach ($socialsStmt->fetchAll() as $social) {
            $socialsBySponsor[$social['sponsor_id']][] = [
                'label' => $social['label'],
                'icon' => $social['icon'],
                'url' => $social['url'],
            ];
        }

        return array_map(function (array $sponsor) use ($socialsBySponsor) {
            return [
                'name' => $sponsor['name'],
                'category' => $sponsor['category'],
                'category_label' => $sponsor['category_label'],
                'icon' => $sponsor['icon'],
                'image' => $sponsor['image'],
                'subtitle' => $sponsor['subtitle'],
                'summary' => $sponsor['summary'],
                'description' => $sponsor['description'] !== null && $sponsor['description'] !== ''
                    ? explode("\n\n", $sponsor['description'])
                    : [],
                'socials' => $socialsBySponsor[$sponsor['id']] ?? [],
                'map' => $sponsor['map'] ?? '',
            ];
        }, $sponsors);
    } catch (Throwable $e) {
        return get_sponsors_fallback();
    }
}

// Respaldo estático (copia congelada de los datos previos a la migración a
// BD), usado solo si la consulta a hive_db falla.
function get_sponsors_fallback(): array {
    return [
        [
            'name' => 'Instituto Franco Condado', 'category' => 'escuelas', 'category_label' => 'Escuelas',
            'icon' => 'graduation-cap', 'image' => 'assets/img/patrocinadores/franco.jpeg',
            'subtitle' => 'Institución educativa de vanguardia',
            'summary' => 'Formación integral en preparatoria, idiomas, secundaria y cursos especializados.',
            'description' => [
                'Una institución educativa de vanguardia, comprometida con brindar una formación de alto nivel y resultados excepcionales.',
                'Nuestro enfoque integral nos permite ofrecer una amplia gama de servicios en distintos sectores, incluyendo Preparatoria, enseñanza de idiomas, secundaria y cursos especializados de bachillerato para empresas, adaptándonos a las necesidades de cada estudiante y organización.',
            ],
            'socials' => [
                ['label' => 'Facebook', 'icon' => 'facebook', 'url' => 'https://www.facebook.com/institutofrancoc'],
                ['label' => 'Instagram', 'icon' => 'instagram', 'url' => 'https://www.instagram.com/ifrancocondado/'],
                ['label' => 'TikTok', 'icon' => 'music-2', 'url' => 'https://www.tiktok.com/@institutofrancocondadoo'],
                ['label' => 'YouTube', 'icon' => 'youtube', 'url' => 'https://www.youtube.com/@InstitutoFrancoCondado'],
                ['label' => 'App', 'icon' => 'smartphone', 'url' => 'https://play.google.com/store/apps/details?id=franco.m.institutofranco10&pli=1'],
            ],
            'map' => 'https://www.google.com/maps/embed?pb=!1m18!1m12!1m3!1d15073.06999937279!2d-99.48457944458005!3d19.183515300000014!2m3!1f0!2f0!2f0!3m2!1i1024!2i768!4f13.1!3m3!1m2!1s0x85cdf3d287ae35cd%3A0xfb4954fa93ff3816!2sInstituto%20Franco%20Condado!5e0!3m2!1ses!2smx!4v1778878114802!5m2!1ses!2smx',
        ],
        [
            'name' => 'Colegio Brusel', 'category' => 'escuelas', 'category_label' => 'Escuelas',
            'icon' => 'graduation-cap', 'image' => 'assets/img/patrocinadores/Colegiobrusel.jpg?v=20260714',
            'subtitle' => 'Formación integral con valores',
            'summary' => 'Educación de calidad centrada en aprendizaje, valores y desarrollo personal.',
            'description' => [
                'El Colegio Brusel es una institución educativa comprometida con la formación integral de sus estudiantes, promoviendo una educación de calidad basada en el aprendizaje, los valores y el desarrollo de habilidades que contribuyan a su crecimiento académico y personal.',
                'A través de un ambiente de enseñanza cercano y un enfoque centrado en el alumno, busca fortalecer el pensamiento, la responsabilidad y el trabajo en equipo, preparando a niñas y niños para enfrentar con éxito los retos de cada etapa de su formación.',
            ],
            'socials' => [
                ['label' => 'Facebook', 'icon' => 'facebook', 'url' => 'https://www.facebook.com/profile.php?id=100070813053345&mibextid=wwXIfr&rdid=SRv4z2Pn0LvtUbJg&share_url=https%3A%2F%2Fwww.facebook.com%2Fshare%2F17x9JX2g18%2F%3Fmibextid%3DwwXIfr'],
            ],
            'map' => 'https://www.google.com/maps/embed?pb=!1m18!1m12!1m3!1d2762.477173533453!2d-99.41282160000002!3d19.1797993!2m3!1f0!2f0!3f0!3m2!1i1024!2i768!4f13.1!3m3!1m2!1s0x85cdf1ab3cd03671%3A0xc2dad4dadccf1d3b!2sColegio%20Brussel!5e1!3m2!1ses!2smx!4v1783963612475!5m2!1ses!2smx',
        ],
        [
            'name' => 'City Dogs', 'category' => 'mascotas', 'category_label' => 'Mascotas',
            'icon' => 'paw-print', 'image' => 'assets/img/patrocinadores/CITYDOGS.jpg',
            'subtitle' => 'Veterinaria y cuidado integral',
            'summary' => 'Atención médica, estética, alimentos y artículos para mascotas.',
            'description' => [
                'City Dogs es una veterinaria dedicada al cuidado integral de animales pequeños y grandes. Ofrece atención médica profesional, estética canina y felina, además de la venta de alimentos, accesorios y artículos especializados para el bienestar de las mascotas.',
                'Servicios: consulta veterinaria general y especializada, vacunación, desparasitación, estética canina y felina, venta de alimentos balanceados, accesorios, ropa, juguetes y atención a animales pequeños y grandes.',
            ],
            'socials' => [
                ['label' => 'Facebook', 'icon' => 'facebook', 'url' => 'https://www.facebook.com/citydogsvet'],
            ],
            'map' => 'https://www.google.com/maps/embed?pb=!1m18!1m12!1m3!1d3768.201845950527!2d-99.42171522649271!3d19.186384348501218!2m3!1f0!2f0!3f0!3m2!1i1024!2i768!4f13.1!3m3!1m2!1s0x85cdf170e4f07a35%3A0xd88451b398c310ce!2sVeterinaria%20%22City%20Dogs%22!5e0!3m2!1ses!2smx!4v1778883520637!5m2!1ses!2smx',
        ],
        [
            'name' => 'Súper Dulce', 'category' => 'comida', 'category_label' => 'Comida y dulces',
            'icon' => 'candy', 'image' => 'assets/img/patrocinadores/SUPERDULCE.jpg',
            'subtitle' => 'Dulces, piñatas y artículos de fiesta',
            'summary' => 'Variedad, color y diversión para fiestas y celebraciones.',
            'description' => [
                'Super Dulce es la tienda ideal para endulzar cada momento. Cuenta con dulces nacionales e importados, piñatas personalizadas, globos, adornos y artículos de fiesta para todas las edades.',
                'Se distingue por su variedad, calidad y precios accesibles, siempre ofreciendo un servicio amable para que tus eventos sean inolvidables.',
            ],
            'socials' => [
                ['label' => 'Facebook', 'icon' => 'facebook', 'url' => 'https://www.facebook.com/profile.php?id=61577991446515'],
            ],
            'map' => 'https://www.google.com/maps/embed?pb=!1m18!1m12!1m3!1d3768.3838976269626!2d-99.47404742649297!3d19.178427748752338!2m3!1f0!2f0!3f0!3m2!1i1024!2i768!4f13.1!3m3!1m2!1s0x85cdf300171643fd%3A0xa03c807e1eceaac0!2sS%C3%BAper%20Dulce!5e0!3m2!1ses!2smx!4v1778883592431!5m2!1ses!2smx',
        ],
        [
            'name' => 'Corazón de Montaña Running', 'category' => 'bienestar', 'category_label' => 'Bienestar',
            'icon' => 'mountain', 'image' => 'assets/img/patrocinadores/CORAZ%C3%93NDE%20MONTA%C3%91A.jpg',
            'subtitle' => 'Running, senderismo y comunidad',
            'summary' => 'Bienestar físico, mental y emocional en contacto con la naturaleza.',
            'description' => [
                'Corazón de Montaña es un club de running y senderismo que promueve el bienestar físico, mental y emocional a través del contacto con la naturaleza.',
                'Más que un grupo deportivo, es una comunidad que inspira disciplina, compañerismo y superación personal, recorriendo cada kilómetro con pasión y propósito.',
            ],
            'socials' => [
                ['label' => 'Facebook', 'icon' => 'facebook', 'url' => 'https://www.facebook.com/CORARUNNING'],
                ['label' => 'Instagram', 'icon' => 'instagram', 'url' => 'https://www.instagram.com/corazonm2021/'],
            ],
            'map' => 'https://www.google.com/maps/embed?pb=!1m18!1m12!1m3!1d3768.194210220682!2d-99.4274076!3d19.186718!2m3!1f0!2f0!3f0!3m2!1i1024!2i768!4f13.1!3m3!1m2!1s0x85cdf1096efbf8a7%3A0x57b83e37ea877499!2sAv.%20Ej%C3%A9rcito%20del%20Trabajo%20220%2C%20Rojastitlan%2C%2052650%20Santiago%20Tilapa%2C%20M%C3%A9x.!5e0!3m2!1ses!2smx!4v1778883764973!5m2!1ses!2smx',
        ],
        [
            'name' => 'Gym Power Fitness Workout Zumba', 'category' => 'bienestar', 'category_label' => 'Bienestar',
            'icon' => 'dumbbell', 'image' => 'assets/img/patrocinadores/GYMPOWER.jpg',
            'subtitle' => 'Entrenamiento, zumba y nutrición',
            'summary' => 'Entrenadores certificados, equipo funcional y asesoría nutricional.',
            'description' => [
                'Gym Power Fitness Workout Zumba es el espacio ideal para quienes buscan transformar su cuerpo y su mente.',
                'Cuenta con entrenadores certificados por la Federación de Constructivismo y la Federación en Zumba, equipo funcional de primera calidad y asesorías nutricionales personalizadas.',
            ],
            'socials' => [
                ['label' => 'Facebook', 'icon' => 'facebook', 'url' => 'https://www.facebook.com/profile.php?id=61579734628972'],
            ],
            'map' => 'https://www.google.com/maps/embed?pb=!1m18!1m12!1m3!1d3768.194210220682!2d-99.4274076!3d19.186718!2m3!1f0!2f0!3f0!3m2!1i1024!2i768!4f13.1!3m3!1m2!1s0x85cdf1096efbf8a7%3A0x57b83e37ea877499!2sAv.%20Ej%C3%A9rcito%20del%20Trabajo%20220%2C%20Rojastitlan%2C%2052650%20Santiago%20Tilapa%2C%20M%C3%A9x.!5e0!3m2!1ses!2smx!4v1778883849166!5m2!1ses!2smx',
        ],
        [
            'name' => 'Traviesos Pet Shop', 'category' => 'mascotas', 'category_label' => 'Mascotas',
            'icon' => 'paw-print', 'image' => 'assets/img/patrocinadores/TRAVIESOSPETSHOP.jpg',
            'subtitle' => 'Juguetes, alimento y accesorios',
            'summary' => 'Productos para consentir perros y gatos con calidad y cariño.',
            'description' => [
                'Traviesos Pet Shop es el lugar perfecto para quienes aman consentir a sus mascotas.',
                'Encontrarás juguetes, alimentos de alta calidad y accesorios ideales para perros y gatos, pensados para su comodidad, diversión y bienestar.',
            ],
            'socials' => [
                ['label' => 'Facebook', 'icon' => 'facebook', 'url' => 'https://www.facebook.com/profile.php?id=61577991446515'],
            ],
            'map' => 'https://www.google.com/maps/embed?pb=!1m18!1m12!1m3!1d3768.3078902904026!2d-99.4172401264928!3d19.18175004864745!2m3!1f0!2f0!3f0!3m2!1i1024!2i768!4f13.1!3m3!1m2!1s0x85cdf100525a618f%3A0xfadeff22471dc8ed!2zVHJhdmllc29zIFBldCBTaG9wIPCfkLbinaTvuI_wn5Cx!5e0!3m2!1ses!2smx!4v1778883926934!5m2!1ses!2smx',
        ],
        [
            'name' => 'Hermes Consultores', 'category' => 'servicios', 'category_label' => 'Servicios',
            'icon' => 'briefcase', 'image' => 'assets/img/patrocinadores/hermesconsultores.jpg',
            'subtitle' => 'Asesorías patrimoniales y seguridad social',
            'summary' => 'Orientación gratuita sobre pensión, derechos, Mejoravit y PPR.',
            'description' => [
                'Hermes Consultores es una firma especializada en brindar asesorías gratuitas sobre temas patrimoniales y de seguridad social.',
                'Ofrece orientación en recuperación de derechos, trámites de pensión IMSS e ISSSTE, proyectos de pensión, Mejoravit, PPR y más.',
            ],
            'socials' => [
                ['label' => 'Facebook', 'icon' => 'facebook', 'url' => 'https://www.facebook.com/profile.php?id=61553624805238'],
            ],
            'map' => 'https://www.google.com/maps/embed?pb=!1m18!1m12!1m3!1d3768.3215790894765!2d-99.46700442649286!3d19.18115174866639!2m3!1f0!2f0!3f0!3m2!1i1024!2i768!4f13.1!3m3!1m2!1s0x85cdf3705f293893%3A0xe77168228d617553!2sHermes%20Consultores!5e0!3m2!1ses!2smx!4v1778883998823!5m2!1ses!2smx',
        ],
        [
            'name' => 'Comedor Familiar Doña Gir', 'category' => 'comida', 'category_label' => 'Comida y dulces',
            'icon' => 'utensils', 'image' => 'assets/img/patrocinadores/COMEDORFAMILIAR.jpg',
            'subtitle' => 'Comida casera y ambiente familiar',
            'summary' => 'Guisados variados preparados al momento con toque casero.',
            'description' => [
                'En Comedor Familiar Doña Gir cada platillo está hecho con el corazón.',
                'Ofrece guisados variados, ingredientes frescos y un ambiente cálido, familiar y lleno de sabor.',
            ],
            'socials' => [
                ['label' => 'Facebook', 'icon' => 'facebook', 'url' => 'https://www.facebook.com/cocinagir'],
            ],
            'map' => 'https://www.google.com/maps/embed?pb=!1m18!1m12!1m3!1d3767.9516289229177!2d-99.46917242649234!3d19.197314948156198!2m3!1f0!2f0!3f0!3m2!1i1024!2i768!4f13.1!3m3!1m2!1s0x85cdf30000a49177%3A0x5cf198c9e7151f2!2sComedor%20Familiar%20Do%C3%B1a%20Gir!5e0!3m2!1ses!2smx!4v1778884058635!5m2!1ses!2smx',
        ],
        [
            'name' => 'Son Mis Alas I.A.P.', 'category' => 'social', 'category_label' => 'Social',
            'icon' => 'heart-handshake', 'image' => 'assets/img/patrocinadores/SONMISALAS.jpg',
            'subtitle' => 'Apoyo a niñas y niños con epidermólisis bullosa',
            'summary' => 'Acompañamiento médico, emocional y social para familias.',
            'description' => [
                'Son Mis Alas I.A.P. es una institución sin fines de lucro dedicada a brindar apoyo integral a niños y niñas que viven con epidermólisis bullosa.',
                'Trabaja con programas de acompañamiento médico, emocional y social para mejorar la calidad de vida y ofrecer esperanza a las familias.',
            ],
            'socials' => [
                ['label' => 'Facebook', 'icon' => 'facebook', 'url' => 'https://www.facebook.com/sonmisalasIAP'],
                ['label' => 'Instagram', 'icon' => 'instagram', 'url' => 'https://www.instagram.com/sonmisalasiap/'],
                ['label' => 'TikTok', 'icon' => 'music-2', 'url' => 'https://www.tiktok.com/@sonmisalasiap'],
            ],
            'map' => 'https://www.google.com/maps/embed?pb=!1m18!1m12!1m3!1d3768.1511410762096!2d-99.42301562649266!3d19.188599848431306!2m3!1f0!2f0!3f0!3m2!1i1024!2i768!4f13.1!3m3!1m2!1s0x85cdf14fdbb4bfbd%3A0xbce04a5a60f9b3c6!2sSon%20Mis%20Alas%2C%20I.A.P.!5e0!3m2!1ses!2smx!4v1778884125794!5m2!1ses!2smx',
        ],
        [
            'name' => 'Nutrycia', 'category' => 'bienestar', 'category_label' => 'Bienestar',
            'icon' => 'apple', 'image' => 'assets/img/patrocinadores/NUTRYCIA.jpg',
            'subtitle' => 'Consultas nutricionales personalizadas',
            'summary' => 'Planes únicos, seguimiento y educación alimentaria.',
            'description' => [
                'Nutricya te acompaña en tu camino hacia una vida más saludable, con consultas personalizadas, control de patologías nutricionales, seguimientos continuos y estrategias para mejorar tu composición corporal.',
                'Su compromiso es ayudarte a alcanzar bienestar físico y emocional a través de educación alimentaria, acompañamiento profesional y hábitos sostenibles.',
            ],
            'socials' => [
                ['label' => 'Facebook', 'icon' => 'facebook', 'url' => 'https://www.facebook.com/profile.php?id=100063671493497'],
            ],
            'map' => '',
        ],
        [
            'name' => 'CONALEP Santiago Tilapa', 'category' => 'escuelas', 'category_label' => 'Escuelas',
            'icon' => 'graduation-cap', 'image' => 'assets/img/patrocinadores/CONALEP.jpg',
            'subtitle' => 'Profesional Técnico Bachiller',
            'summary' => 'Contabilidad, Industria del Vestido, Seguridad e Higiene y Protección Civil.',
            'description' => [
                'El Plantel CONALEP Santiago Tilapa ofrece carreras de Profesional Técnico Bachiller en Contabilidad, Industria del Vestido, Seguridad e Higiene y Protección Civil.',
                'Forma jóvenes líderes, comprometidos y preparados para enfrentar los retos del futuro, combinando excelencia académica con valores y desarrollo profesional.',
            ],
            'socials' => [
                ['label' => 'Facebook', 'icon' => 'facebook', 'url' => 'https://www.facebook.com/PlantelSantiagoTilapa'],
            ],
            'map' => 'https://www.google.com/maps/embed?pb=!1m18!1m12!1m3!1d3768.1780539248284!2d-99.43509902649265!3d19.18742394846843!2m3!1f0!2f0!3f0!3m2!1i1024!2i768!4f13.1!3m3!1m2!1s0x85cdf10bbed6708d%3A0xf07ad6ffab2675d4!2sConalep%20Santiago%20Tilapa!5e0!3m2!1ses!2smx!4v1778884237890!5m2!1ses!2smx',
        ],
        [
            'name' => 'Kinbux', 'category' => 'tecnologia', 'category_label' => 'Tecnología',
            'icon' => 'smartphone', 'image' => 'assets/img/patrocinadores/KINBUX.jpg',
            'subtitle' => 'Tecnología accesible e innovadora',
            'summary' => 'Gadgets, accesorios y productos originales de marcas reconocidas.',
            'description' => [
                'Kinbux impulsa a la juventud a través de la tecnología, ofreciendo productos originales y de calidad como distribuidores autorizados de marcas reconocidas.',
                'Cada gadget, accesorio o dispositivo es una oportunidad de aprender, crear y disfrutar, haciendo de la tecnología una herramienta para crecer.',
            ],
            'socials' => [
                ['label' => 'Facebook', 'icon' => 'facebook', 'url' => 'https://www.facebook.com/kinbux'],
                ['label' => 'Instagram', 'icon' => 'instagram', 'url' => 'https://www.instagram.com/kinbux.oficial/'],
                ['label' => 'TikTok', 'icon' => 'music-2', 'url' => 'https://www.tiktok.com/@kinbux.oficial'],
            ],
            'map' => '',
        ],
        [
            'name' => 'IMJUVE', 'category' => 'social', 'category_label' => 'Social',
            'icon' => 'landmark', 'image' => 'assets/img/patrocinadores/IMJUVET.jpg',
            'subtitle' => 'Desarrollo integral de la juventud',
            'summary' => 'Programas culturales, deportivos, sociales y educativos.',
            'description' => [
                'IMJUVET es una institución dedicada a impulsar el desarrollo integral de la juventud tianguistecana.',
                'A través de programas culturales, deportivos, sociales y educativos, fomenta la participación activa, liderazgo y crecimiento personal de los jóvenes.',
            ],
            'socials' => [
                ['label' => 'Facebook', 'icon' => 'facebook', 'url' => 'https://www.facebook.com/profile.php?id=61571535178138'],
            ],
            'map' => 'https://www.google.com/maps/embed?pb=!1m14!1m8!1m3!1d3768.319038322537!2d-99.4699855!3d19.1812628!3m2!1i1024!2i768!4f13.1!3m3!1m2!1s0x85cd89ce905d9961%3A0x2732249acb0862f7!2sDIF%20Sistema%20Municipal%20para%20el%20Desarroll%C3%B3%20Integral%20de%20la%20Familia%20de%20Tianguistenco!5e0!3m2!1ses!2smx!4v1778881037333!5m2!1ses!2smx',
        ],
        [
            'name' => 'CBTa 96', 'category' => 'escuelas', 'category_label' => 'Escuelas',
            'icon' => 'graduation-cap', 'image' => 'assets/img/patrocinadores/cbtanoventayseis.jpeg',
            'subtitle' => 'Formación media superior agropecuaria',
            'summary' => 'Educación académica y técnica con práctica en campo.',
            'description' => [
                'El CBTa No. 96 de Xalatlaco es una institución de nivel medio superior enfocada en la formación académica y técnica de jóvenes, con especial énfasis en el área agropecuaria.',
                'Su modelo combina aprendizaje en aula y práctica en campo, promoviendo habilidades, valores, nuevas tecnologías, innovación y compromiso comunitario.',
            ],
            'socials' => [
                ['label' => 'Facebook', 'icon' => 'facebook', 'url' => 'https://www.facebook.com/c.b.t.a.no.96'],
                ['label' => 'TikTok', 'icon' => 'music-2', 'url' => 'https://www.tiktok.com/@cbta.96?is_from_webapp=1&sender_device=pc'],
            ],
            'map' => 'https://www.google.com/maps/embed?pb=!1m18!1m12!1m3!1d3768.353043694687!2d-99.43028442649288!3d19.179776448709763!2m3!1f0!2f0!3f0!3m2!1i1024!2i768!4f13.1!3m3!1m2!1s0x85cdf1a6d8396d95%3A0x8d6627ab6a874efa!2sCBTa%2096!5e0!3m2!1ses!2smx!4v1778882970764!5m2!1ses!2smx',
        ],
        [
            'name' => 'La Mirafuente de Soda', 'category' => 'comida', 'category_label' => 'Comida y dulces',
            'icon' => 'utensils', 'image' => 'assets/img/patrocinadores/lamirafuente.jpeg',
            'subtitle' => 'Bebidas y snacks',
            'summary' => 'Refrescos, aguas frescas, jugos  y botanas para cada antojo.',
            'description' => [
                'Somos un establecimiento dedicado a brindarte una experiencia distinta, donde podrás disfrutar de excelentes bebidas y snacks en compañía de tus seres queridos.',
            ],
            'socials' => [
                ['label' => 'Facebook', 'icon' => 'facebook', 'url' => 'https://www.facebook.com/share/1HEop9AFhL/?mibextid=wwXIfr'],
                ['label' => 'Instagram', 'icon' => 'instagram', 'url' => 'https://www.instagram.com/lamirafuente?igsh=cGlpYWQwNXcyZ2o2'],
            ],
            'map' => 'https://www.google.com/maps/embed?pb=!1m14!1m8!1m3!1d3768.0385692435025!2d-99.46336364746094!3d19.193517684936523!3m2!1i1024!2i768!4f13.1!3m3!1m2!1s0x85cdf3da6e0228eb%3A0x27fa29fcc0ff798!2sCalle%20Gral%20Venustiano%20Carranza%20217%2C%20Centro%2C%2052700%20Capulhuac%20de%20Mirafuentes%2C%20M%C3%A9x.!5e0!3m2!1ses!2smx!4v1779297517913!5m2!1ses!2smx',
        ],
        [
            'name' => 'Universidad Integral de Estudios Medios y Superiores (UIEMS)', 'category' => 'escuelas', 'category_label' => 'Escuelas',
            'icon' => 'graduation-cap', 'image' => 'assets/img/patrocinadores/UIEMS.jpeg',
            'subtitle' => 'Universidad integral de estudios medios y superiores',
            'summary' => 'La UIEMS es más que una universidad. Es donde transformas tu historia, forjas tu carácter y te lanzas al vuelo con título de validez oficial SEP.',
            'description' => [
                'La UIEMS nació con la convicción de que la educación de calidad debe ser accesible. Hemos formado profesionistas íntegros con visión de futuro y responsabilidad social.',
                'La Universidad Integral de Estudios Medios y Superiores (UIEMS) es una institución educativa, comprometida con la formación integral de jóvenes y adultos, basada en un modelo práctico, flexible con orientación al campo laboral. En UIEMS formamos profesionales capaces de responder a las necesidades reales de la sociedad actual con un amplio sentido ético..',
            ],
            'socials' => [
                ['label' => 'Facebook', 'icon' => 'facebook', 'url' => 'https://www.facebook.com/profile.php?id=100083315463885&rdid=WKuBloU3xxjTbDk3&share_url=https%3A%2F%2Fwww.facebook.com%2Fshare%2F1GKTm5Jp7R%2F'],
                ['label' => 'Instagram', 'icon' => 'instagram', 'url' => 'https://www.instagram.com/uiemssantiago?igsh=MXkxOWl1ZjM4M3hueQ%3D%3D'],
                ['label' => 'TikTok', 'icon' => 'music-2', 'url' => 'https://www.tiktok.com/@universidaduiemssantiago?_r=1&_t=ZS-96fSg6VWxpR'],
                ['label' => 'WhatsApp', 'icon' => 'smartphone', 'url' => 'https://api.whatsapp.com/send/?phone=527225844271&text=Hola%2C+me+gustaría+recibir+más+información+sobre+sus+servicios.&type=phone_number&app_absent=0'],
            ],
            'map' => 'https://www.google.com/maps/embed?pb=!1m18!1m12!1m3!1d2762.402734113186!2d-99.46620469999999!3d19.184237400000004!2m3!1f0!2f0!3f0!3m2!1i1024!2i768!4f13.1!3m3!1m2!1s0x85cdf3006e0257cb%3A0xa2b6b698fb94c248!2sUiems%20Universidad%20Integral%20de%20estudios%20medios%20y%20superiores%20plantel%20Santiago%20Tianguistenco!5e1!3m2!1ses!2smx!4v1780336109584!5m2!1ses!2smx',
        ],
    ];
}

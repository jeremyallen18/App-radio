<?php
// Conexión a la base de datos compartida con App-radio/hive-backend (hive_db).
// Las credenciales viven en config/.env (no se commitean en texto plano);
// config/.env.example documenta las variables esperadas.
//
// get_pdo() cachea la conexión en una variable static: como se invoca desde
// dentro de funciones en inc/data/*.php, un require_once del archivo no
// basta (la segunda llamada a esa función, en la misma request, no
// reejecutaría este archivo y se quedaría sin $pdo). Con la función sí
// se reusa la misma conexión sin reabrirla en cada llamada.
function get_pdo(): PDO {
    static $pdo = null;
    if ($pdo !== null) {
        return $pdo;
    }

    require_once __DIR__ . '/../inc/helpers/env.php';
    load_env(__DIR__ . '/.env');

    // Host del servidor MySQL.
    $host = env_get('DB_HOST') ?: '127.0.0.1';

    // Nombre exacto de la base de datos (compartida con hive-backend).
    $db = env_get('DB_NAME') ?: 'hive_db';

    // Usuario de la base de datos.
    $user = env_get('DB_USER') ?: 'hive_user';

    // Contraseña del usuario de base de datos.
    $pass = env_get('DB_PASS') ?: '';

    try {
        // Creamos la conexión PDO con charset utf8mb4 para soportar todos los caracteres.
        $pdo = new PDO(
            "mysql:host=$host;dbname=$db;charset=utf8mb4",
            $user,
            $pass
        );

        // Activa excepciones para detectar errores SQL de forma controlada.
        $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

        // Define resultado asociativo por defecto en consultas fetch.
        $pdo->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_ASSOC);

        // Zona horaria de la SESIÓN de MySQL (no la de PHP): inc/data/live_comments.php
        // calcula todo con NOW()/created_at del propio MySQL a propósito, para
        // no mezclar relojes de PHP y MySQL. En XAMPP local el motor ya corre
        // en hora de México (config del SO), pero en Hostinger MySQL arranca
        // en UTC -> sin esto los timestamps salen 6h adelantados. Offset fijo
        // (no nombre de zona) porque hosting compartido normalmente no trae
        // cargadas las tablas de zonas horarias de MySQL; México ya no cambia
        // de horario (DST abolido desde 2022 salvo franja fronteriza), así que
        // un offset fijo no se desactualiza.
        $pdo->exec("SET time_zone = '-06:00'");
    } catch (PDOException $e) {
        // Lanzamos un error genérico para que la página decida cómo mostrarlo.
        throw new RuntimeException("Error de conexión a la base de datos.");
    }

    return $pdo;
}

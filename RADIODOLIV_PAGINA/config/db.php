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
    $host = getenv('DB_HOST') ?: '127.0.0.1';

    // Nombre exacto de la base de datos (compartida con hive-backend).
    $db = getenv('DB_NAME') ?: 'hive_db';

    // Usuario de la base de datos.
    $user = getenv('DB_USER') ?: 'hive_user';

    // Contraseña del usuario de base de datos.
    $pass = getenv('DB_PASS') ?: '';

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
    } catch (PDOException $e) {
        // Lanzamos un error genérico para que la página decida cómo mostrarlo.
        throw new RuntimeException("Error de conexión a la base de datos.");
    }

    return $pdo;
}

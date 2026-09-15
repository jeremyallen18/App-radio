<?php
// Carga variables desde un archivo .env y las guarda en un almacen interno.
// Usado por config/db.php y por inc/api/dolibot-chat.php para no duplicar
// el parser en cada lugar que necesita leer config/.env.
//
// No se usa putenv()/getenv() porque algunos hostings compartidos (p. ej.
// InfinityFree) tienen putenv() deshabilitada por seguridad: se ejecuta sin
// error pero no guarda nada. En su lugar, las variables se acumulan en un
// static dentro de env_store() y env_get() las lee desde ahi.
//
// El almacen es un static de funcion (no una global ni una variable de
// nivel superior) a proposito: este archivo se incluye con require_once
// desde dentro de get_pdo() en config/db.php, asi que una asignacion de
// nivel superior caeria en el scope de esa funcion y no seria compartida.

// Referencia al array-almacen compartido. Se pasa por referencia para que
// tanto load_env() como env_get() escriban/lean el mismo array.
function &env_store(): array {
    static $vars = [];
    return $vars;
}

function load_env(string $path): void {
    if (!is_file($path)) return;
    $store = &env_store();
    foreach (file($path, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) as $line) {
        $line = trim($line);
        if ($line === '' || $line[0] === '#') continue;
        [$key, $value] = array_pad(explode('=', $line, 2), 2, '');
        $key = trim($key);
        $value = trim($value);
        if ($key !== '' && !array_key_exists($key, $store)) {
            $store[$key] = $value;
        }
    }
}

// Reemplazo de getenv(): devuelve la variable cargada por load_env() o
// $default si no existe.
function env_get(string $key, $default = null) {
    $store = &env_store();
    return array_key_exists($key, $store) ? $store[$key] : $default;
}

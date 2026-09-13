<?php
// Actor identity and audit trail for the public content API (/site/* routes).
// See docs/site-content-api.md for full endpoint contract.

// API key scopes; prepares for fine-grained permissions without changing
// this function or calling code.
const SITE_CONTENT_SCOPES = ['site:read', 'site:write', 'site:delete'];

// Returns X-Api-Key header value from $_SERVER or getallheaders(), or null.
function site_request_api_key(): ?string {
    if (isset($_SERVER['HTTP_X_API_KEY']) && $_SERVER['HTTP_X_API_KEY'] !== '') {
        return trim((string) $_SERVER['HTTP_X_API_KEY']);
    }
    if (function_exists('getallheaders')) {
        foreach (getallheaders() as $name => $value) {
            if (strcasecmp($name, 'X-Api-Key') === 0) {
                return trim((string) $value);
            }
        }
    }
    return null;
}

function site_request_ip(): ?string {
    return isset($_SERVER['REMOTE_ADDR']) ? (string) $_SERVER['REMOTE_ADDR'] : null;
}

// Returns auth context from session (director) or X-Api-Key. Scope $requiredScope
// is validated against actor's scopes.
function site_actor_context(PDO $pdo, string $requiredScope = 'site:write'): array {
    $configuredKey = (string) env_get('SITE_CONTENT_KEY', '');
    if ($configuredKey !== '') {
        if (APP_ENV === 'production' && strlen($configuredKey) < 32) {
            error_response('Configuración inválida: SITE_CONTENT_KEY debe tener al menos 32 caracteres en producción', 500);
        }
        $sentKey = site_request_api_key();
        if ($sentKey !== null && hash_equals($configuredKey, $sentKey)) {
            $context = [
                'actor_type'  => 'api_key',
                'actor_id'    => 'site_content_integration',
                'actor_email' => null,
                'role'        => 'system',
                'scopes'      => SITE_CONTENT_SCOPES,
            ];
            site_require_scope($context, $requiredScope);
            site_enforce_write_rate_limit($pdo, $context, $requiredScope);
            return $context;
        }
    }

    $user = require_auth($pdo);
    require_role($user, ['director']);
    $context = [
        'actor_type'  => 'session',
        'actor_id'    => (string) $user['id'],
        'actor_email' => $user['email'],
        'role'        => $user['role'],
        'scopes'      => SITE_CONTENT_SCOPES,
    ];
    site_enforce_write_rate_limit($pdo, $context, $requiredScope);
    return $context;
}

// Límite común a los 12 endpoints create/update/delete de /site/* (incluye
// las subidas de imagen/audio, el mayor riesgo de agotar el disco
// compartido). Las lecturas (site:read) no pasan por aquí.
function site_enforce_write_rate_limit(PDO $pdo, array $context, string $requiredScope): void {
    if ($requiredScope === 'site:read') return;
    enforce_rate_limit($pdo, 'site_content_write', $context['actor_id'], 30, 3600);
}

function site_require_scope(array $actorContext, string $scope): void {
    if (!in_array($scope, $actorContext['scopes'], true)) {
        error_response("La credencial usada no tiene el alcance requerido: $scope", 403);
    }
}

// Saves audit record. $before/$after stored as JSON for reconstruction;
// $resource must match /site/{resource} segment for endpoint filtering.
function site_audit_log(
    PDO $pdo,
    array $actorContext,
    string $resource,
    string $action,
    ?int $recordId,
    ?array $before = null,
    ?array $after = null
): void {
    $stmt = $pdo->prepare(
        'INSERT INTO site_content_audit_log
            (resource, action, record_id, actor_type, actor_id, actor_email, request_ip, before_json, after_json)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)'
    );
    $stmt->execute([
        $resource,
        $action,
        $recordId,
        $actorContext['actor_type'],
        $actorContext['actor_id'],
        $actorContext['actor_email'],
        site_request_ip(),
        $before !== null ? json_encode($before) : null,
        $after !== null ? json_encode($after) : null,
    ]);
}

// ---- versioned responses -------------------------------------------
// All /site/* responses include 'version' => '1' for client detection.

function site_response_item(array $item, int $status = 200): void {
    json_response(['version' => '1', 'item' => $item], $status);
}

function site_response_list(array $items): void {
    json_response(['version' => '1', 'items' => $items]);
}

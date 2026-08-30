<!-- "Pide tu canción": el boton dentro del reproductor (ver index.php,
     #songRequestOpen) abre este cuadro de dialogo. El envio arma un mensaje
     de WhatsApp con la cancion y la dedicatoria (ambos ya validados en el
     script de index.php) hacia el mismo numero de contacto que usa DoliBot. -->
<div class="song-request-modal" id="song-request-modal" aria-hidden="true" data-page-content>
    <div class="song-request-modal-overlay" data-close-song-request="true"></div>
    <div class="song-request-modal-card" role="dialog" aria-modal="true" aria-labelledby="song-request-title">
        <button class="song-request-modal-close" id="song-request-close" type="button" aria-label="Cerrar formulario de solicitud">
            <i data-lucide="x"></i>
        </button>

        <div class="song-request-modal-head">
            <span class="song-request-eyebrow"><i data-lucide="music-2"></i> Pide tu canción</span>
            <h2 id="song-request-title">Solicita tu canción</h2>
            <p>Dinos qué quieres escuchar y, si quieres, agrega una dedicatoria. Tu pedido se envía por WhatsApp directo a Radio Doliv.</p>
        </div>

        <form id="song-request-form" class="song-request-form" novalidate>
            <label class="song-request-field" for="song-request-song">
                <span>Canción y artista</span>
                <input type="text" id="song-request-song" name="song" placeholder="Ej. Bohemian Rhapsody - Queen" autocomplete="off" required>
            </label>

            <label class="song-request-field" for="song-request-dedication">
                <span>Dedicatoria (opcional)</span>
                <textarea id="song-request-dedication" name="dedication" rows="3" placeholder="Ej. Para Ana, de parte de Luis 💙"></textarea>
            </label>

            <p class="song-request-error" id="song-request-error" role="alert"></p>

            <button type="submit" class="song-request-submit">
                <i data-lucide="send"></i> Pide tu canción con Radio Doliv
            </button>
        </form>
    </div>
</div>

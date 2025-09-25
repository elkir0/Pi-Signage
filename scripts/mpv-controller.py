#!/usr/bin/env python3
"""
PiSignage MPV Controller
Contrôle avancé de MPV via socket IPC
"""

import json
import socket
import sys
import glob
import os
import time

class MPVController:
    def __init__(self):
        self.socket_path = "/tmp/mpv-socket"
        self.media_dir = "/opt/pisignage/media"
        self.playlist_file = "/opt/pisignage/playlists/main.m3u"
        self.fallback_image = "/opt/pisignage/media/fallback-logo.jpg"

    def send_command(self, command):
        """Envoie une commande à MPV via socket"""
        try:
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
                s.connect(self.socket_path)
                s.sendall(json.dumps(command).encode() + b'\n')
                response = s.recv(4096)
                return json.loads(response.decode())
        except FileNotFoundError:
            return {"error": "MPV not running or socket not found"}
        except Exception as e:
            return {"error": str(e)}

    def play(self):
        """Reprendre la lecture"""
        return self.send_command({"command": ["set", "pause", False]})

    def pause(self):
        """Mettre en pause"""
        return self.send_command({"command": ["set", "pause", True]})

    def next(self):
        """Piste suivante"""
        return self.send_command({"command": ["playlist-next"]})

    def previous(self):
        """Piste précédente"""
        return self.send_command({"command": ["playlist-prev"]})

    def stop(self):
        """Arrêter MPV"""
        return self.send_command({"command": ["quit"]})

    def volume(self, level):
        """Ajuster le volume (0-100)"""
        return self.send_command({"command": ["set", "volume", int(level)]})

    def seek(self, seconds):
        """Avancer/reculer de X secondes"""
        return self.send_command({"command": ["seek", seconds, "relative"]})

    def reload_playlist(self):
        """Recharge la playlist depuis le dossier media"""
        # Trouve tous les fichiers média
        media_files = []
        for ext in ['*.mp4', '*.avi', '*.mkv', '*.mov', '*.webm', '*.jpg', '*.png']:
            media_files.extend(glob.glob(os.path.join(self.media_dir, ext)))

        media_files.sort()

        if not media_files and os.path.exists(self.fallback_image):
            media_files = [self.fallback_image]

        # Écrit la playlist
        os.makedirs(os.path.dirname(self.playlist_file), exist_ok=True)
        with open(self.playlist_file, 'w') as f:
            for file in media_files:
                f.write(f"{file}\n")

        # Recharge dans MPV
        result = self.send_command({
            "command": ["loadlist", self.playlist_file, "replace"]
        })

        return {
            "playlist_reloaded": True,
            "files_count": len(media_files),
            "files": [os.path.basename(f) for f in media_files],
            "mpv_response": result
        }

    def status(self):
        """Affiche le statut détaillé"""
        status_info = {}

        # Liste des propriétés à récupérer
        properties = [
            "filename",
            "pause",
            "playback-time",
            "duration",
            "volume",
            "playlist-pos",
            "playlist-count",
            "video-format",
            "video-codec",
            "width",
            "height",
            "fps"
        ]

        for prop in properties:
            result = self.send_command({"command": ["get_property", prop]})
            if result and "data" in result:
                status_info[prop] = result["data"]
            elif result and "error" in result:
                status_info[prop] = None

        # Format human-readable
        if status_info.get("playback-time") and status_info.get("duration"):
            pos = status_info["playback-time"]
            dur = status_info["duration"]
            status_info["progress"] = f"{int(pos)}s / {int(dur)}s ({int(pos/dur*100)}%)"

        if status_info.get("width") and status_info.get("height"):
            status_info["resolution"] = f"{status_info['width']}x{status_info['height']}"

        return status_info

    def play_file(self, filename):
        """Jouer un fichier spécifique"""
        filepath = os.path.join(self.media_dir, filename)
        if not os.path.exists(filepath):
            return {"error": f"File not found: {filename}"}

        return self.send_command({
            "command": ["loadfile", filepath, "replace"]
        })

    def screenshot(self):
        """Prendre une capture d'écran"""
        filename = f"/tmp/mpv-screenshot-{int(time.time())}.jpg"
        result = self.send_command({
            "command": ["screenshot-to-file", filename, "video"]
        })
        if result and not result.get("error"):
            result["screenshot"] = filename
        return result


def main():
    """CLI pour contrôler MPV"""
    controller = MPVController()

    if len(sys.argv) < 2:
        print("""Usage: mpv-controller.py [command] [args]

Commands:
    play            - Resume playback
    pause           - Pause playback
    next            - Next file
    previous        - Previous file
    stop            - Stop MPV
    status          - Show detailed status
    reload          - Reload playlist from media folder
    volume [0-100]  - Set volume
    seek [seconds]  - Seek forward/backward
    file [name]     - Play specific file
    screenshot      - Take screenshot
""")
        sys.exit(1)

    command = sys.argv[1]

    try:
        if command == "play":
            result = controller.play()
        elif command == "pause":
            result = controller.pause()
        elif command == "next":
            result = controller.next()
        elif command == "previous":
            result = controller.previous()
        elif command == "stop":
            result = controller.stop()
        elif command == "reload":
            result = controller.reload_playlist()
        elif command == "status":
            result = controller.status()
        elif command == "volume" and len(sys.argv) > 2:
            result = controller.volume(sys.argv[2])
        elif command == "seek" and len(sys.argv) > 2:
            result = controller.seek(sys.argv[2])
        elif command == "file" and len(sys.argv) > 2:
            result = controller.play_file(sys.argv[2])
        elif command == "screenshot":
            result = controller.screenshot()
        else:
            print(f"Unknown command: {command}")
            sys.exit(1)

        print(json.dumps(result, indent=2))

    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
#!/bin/bash

# Pour chaque fichier dans le répertoire courant
for file in *; do
    # Vérifier que le fichier existe et contient un tiret
    if [ -f "$file" ] && [[ "$file" == *-* ]]; then
        # Créer le nouveau nom en remplaçant - par _
        newname=$(echo "$file" | tr '-' '_')
        
        # Renommer le fichier
        mv "$file" "$newname"
        
        echo "Renommé: $file -> $newname"
    fi
done

echo "Terminé! Tous les fichiers ont été renommés."
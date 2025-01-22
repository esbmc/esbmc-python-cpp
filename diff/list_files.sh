#!/bin/bash

# Déclarer un tableau pour stocker les noms de fichiers
declare -a files_array

# Stocker les noms de fichiers dans le tableau
for file in *.py; do
    # Vérifier que le fichier existe et est un fichier régulier
    if [ -f "$file" ]; then
        files_array+=("$file")
    fi
done

# Créer une chaîne avec tous les noms de fichiers
all_files=$(printf "%s " "${files_array[@]}")

# Afficher tous les fichiers en une fois
echo "Fichiers trouvés: $all_files"
echo "Nombre total de fichiers: ${#files_array[@]}"
 # Check if virtual environment already exists
 if [ ! -d "venv" ]; then
     echo "Creating Python virtual environment..."
     python3.12 -m venv venv
 else
     echo "Virtual environment already exists"
 fi

 venv/bin/pip install -r requirements.txt

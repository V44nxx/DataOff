import psycopg2
import sys
import traceback

try:
    conn = psycopg2.connect("postgresql://postgres:dataoff_password@127.0.0.1:5432/dataoff_db")
    print("CONEXION EXITOSA!")
    conn.close()
except Exception as e:
    # Try to decode the error message safely
    err_str = str(e)
    try:
        # Sometimes args are bytes in psycopg2
        if hasattr(e, 'args') and len(e.args) > 0 and isinstance(e.args[0], bytes):
            err_str = e.args[0].decode('utf-8', errors='replace')
    except Exception:
        pass
    print("ERROR DETALLADO:")
    print(err_str)
    traceback.print_exc()

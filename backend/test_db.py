import asyncio
import asyncpg
import sys

async def test_conn():
    try:
        conn = await asyncpg.connect('postgresql://postgres:dataoff_password@127.0.0.1:5432/dataoff_db')
        print("CONEXION EXITOSA!")
        await conn.close()
    except Exception as e:
        print(f"ERROR: {e}")

if __name__ == '__main__':
    if sys.platform == 'win32':
        asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())
    asyncio.run(test_conn())

"""
db_connection.py — Kết nối tới SQL Server (database: data_Hangfolio)
"""

from sqlalchemy import create_engine
import urllib

# Cấu hình kết nối
SERVER = r"desktop-4gg98sv\sqlexpress" 
DATABASE = "data_Hangfolio"            

def get_engine():
    """Tạo và trả về SQLAlchemy engine để Python nói chuyện với SQL Server."""
    # Chuỗi ODBC: khai báo driver, server, database, và Windows Auth
    params = urllib.parse.quote_plus(
        "DRIVER={ODBC Driver 17 for SQL Server};"
        f"SERVER={SERVER};"
        f"DATABASE={DATABASE};"
        "Trusted_Connection=yes;"   # = dùng tài khoản Windows, không cần password
    )
    # SQLAlchemy ngồi trên pyodbc: ta viết lệnh, nó dịch xuống pyodbc đẩy vào SQL Server
    engine = create_engine(f"mssql+pyodbc:///?odbc_connect={params}")
    return engine

# Cho phép chạy trực tiếp file này để TEST kết nối: python db_connection.py
if __name__ == "__main__":
    try:
        engine = get_engine()
        with engine.connect() as conn:
            print("Kết nối SQL Server thành công!")
            print(f"   Server:   {SERVER}")
            print(f"   Database: {DATABASE}")
    except Exception as e:
        print("Kết nối thất bại. Kiểm tra:")
        print("   - SQL Server Express đang chạy")
        print("   - Tên SERVER")
        print("   - Đã cài 'ODBC Driver 17 for SQL Server'")
        print(f"\nChi tiết lỗi: {e}")
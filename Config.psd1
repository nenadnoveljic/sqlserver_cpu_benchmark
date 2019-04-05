@{
    ConnectString = "Server=TZRH-S9026\DED061;Integrated Security=True"
    #ConnectString = "Server=SERVER\INSTANCE ;Database = DB; User ID=USERNAME; Password=PASSWORD"

    Load = "sp_cpu_loop @iterations = 10000000"
}

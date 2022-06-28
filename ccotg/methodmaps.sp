static bool g_bHasRobotArm[MAXPLAYERS + 1];
static bool g_bIsInRespawnRoom[MAXPLAYERS + 1];
static float g_flLastClassChange[MAXPLAYERS + 1];

methodmap Player
{
	public Player(int iClient)
	{
		return view_as<Player>(iClient);
	}
	
	property int iClient
	{
		public get()
		{
			return view_as<int>(this);
		}
	}
	
	property float flLastClassChange
	{
		public get()
		{
			return g_flLastClassChange[this.iClient];
		}
		public set(float flTime)
		{
			g_flLastClassChange[this.iClient] = flTime;
		}
	}
	
	property bool bHasRobotArm
	{
		public get()
		{
			return g_bHasRobotArm[this.iClient];
		}
		public set(bool bHasRobotArm)
		{
			g_bHasRobotArm[this.iClient] = bHasRobotArm;
		}
	}
	
	property bool bIsInRespawnRoom
	{
		public get()
		{
			return g_bIsInRespawnRoom[this.iClient];
		}
		public set(bool bIsInRespawnRoom)
		{
			g_bIsInRespawnRoom[this.iClient] = bIsInRespawnRoom;
		}
	}
	
	public void Reset()
	{
		this.flLastClassChange = GetGameTime();
		this.bIsInRespawnRoom = false;
		this.bHasRobotArm = false;
	}
	
}
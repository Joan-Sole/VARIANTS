USE [parkod]
GO

/****** Object:  Table [dbo].[MARQUE]    Script Date: 01/10/2026 09:34:58 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[MARQUE](
	[CMARQ] [nvarchar](3) NULL,
	[NOMC] [nvarchar](12) NULL,
	[NOML] [nvarchar](36) NULL,
	[INTERNE] [nvarchar](1) NULL,
	[DTCREATION] [nvarchar](8) NULL,
	[DTMAJFICHE] [nvarchar](8) NULL,
	[CFOUR] [nvarchar](10) NULL
) ON [PRIMARY]
GO


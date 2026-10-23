USE [parkod]
GO

/****** Object:  Table [dbo].[LIGNE]    Script Date: 01/10/2026 09:33:07 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[LIGNE](
	[CLIGNE] [nvarchar](2) NULL,
	[NOM] [nvarchar](20) NULL,
	[DTCREATION] [nvarchar](8) NULL,
	[DTMAJFICHE] [nvarchar](8) NULL,
	[CMARQ] [nvarchar](3) NULL,
	[CLEML] [nvarchar](10) NULL
	[CDEP] [nvarchar](2) NULL
) ON [PRIMARY]
GO


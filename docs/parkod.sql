USE [parkod]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[PARKOD](
    [CMARQ]      [nvarchar](3) NOT NULL,
    [CCATEG]     [nvarchar](2) NOT NULL,
    [CPROD]      [nvarchar](3) NOT NULL,

    [CLIGNE]     [nvarchar](2) NULL,
    [DESIGN1]    [nvarchar](18) NULL,
    [DESIGN2]    [nvarchar](18) NULL,
    [DECCONT]    [nvarchar](2) NULL,
    [CONTENANCE] DECIMAL(6,2) NULL,
    [UNITEMESUR] [nvarchar](1) NULL,
    [LIBCOURT]   [nvarchar](15) NULL,
    [NUM_UPD]    [nvarchar](15) NULL,
    [CSSCATEG]   [nvarchar](1) NULL,
	
    [PRIX_ACHAT]  DECIMAL(12,2) NULL,
	

    CONSTRAINT [PK_PARKOD] PRIMARY KEY (
        [CMARQ],
        [CCATEG],
        [CPROD]
    )
) ON [PRIMARY]
GO

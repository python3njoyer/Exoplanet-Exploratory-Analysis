create database star_classification;
use star_classification;


# ---------------------------- Create tables for data import ----------------------------
create table Harvard_Spectral (
	Class char not null unique,
    Min_Temperature_K int,
    Chromaticity varchar(20),
    Percentage_Main_Sequence decimal (20,10),
    primary key (Class));

select Class, Min_Temperature_K, Chromaticity, concat(Percentage_Main_Sequence*100, '%') as Percent_of_Main_Sequence_Stars 
	from Harvard_Spectral
    order by Min_Temperature_K desc;
    
    
create table Yerkes_Spectral (
	Lum_Class varchar (10) not null unique,
    Star_Description varchar (50),
    primary key (Lum_Class));

select * from Yerkes_Spectral;


create table Stars_raw (
	Star_ID varchar(50) not null unique,
    Num_of_Planets int,
    Spectral_Type varchar(20),
    Harvard_Class char 
		check (Harvard_Class in ('O', 'B', 'A', 'F', 'G', 'K', 'M')),
    Yerkes_Class varchar(5),
    Temperature_K float,
    Radius_Solar float,
    Mass_Solar float,
    Distance_Pc float,
    primary key (Star_ID));

select * from Stars_raw
	limit 100;


create table Planets_raw (
	Planet_ID varchar(50) not null unique,
    Host_ID varchar(50) not null,
    Num_Stars tinyint,
    Discovery_Method varchar(30),
    Discovery_Year year,
    Orbit_Period decimal(20,5),
    Orbit_Axis_AU decimal(20,5),
    Earth_Radii decimal(20,5),
    Earth_Masses decimal(20,5),
    M_Msini varchar(10),
    Eccentricity decimal(20,10),
    primary key (Planet_ID),
    foreign key (Host_ID) references Stars_raw (Star_ID));

select * from Planets_raw
	limit 200;


# ---------------------------- Data cleaning ----------------------------

-- create view with cleaned Stars data: 
-- 1. replace empty fields w/ null
-- 2. replace zeros in Temperature column w/ null
-- 3. predict Harvard spectral class based on temperature, replace blanks with predicted value

create view Stars as
	select Star_ID, Num_of_Planets, nullif(Temperature_K, 0) as Temp_K,
		coalesce(nullif(Harvard_Class, ""), 
			case when Temperature_K >= 30000 then 'O'
			when Temperature_K between 10000 and 29999.99 then 'B'
			when Temperature_K between 7500 and 9999.99 then 'A'
			when Temperature_K between 6000 and 7499.99 then 'F'
			when Temperature_K between 5200 and 5999.99 then 'G'
			when Temperature_K between 3700 and 5199.99 then 'K'
			when Temperature_K between 1 and 3699.99 then 'M'
			else null end) as H_Class, 
		nullif(Yerkes_Class, "") as Y_Class, Radius_Solar, Mass_Solar, Distance_Pc
	from Stars_raw;


-- create view for cleaned Planet data:
-- 1. replace zeros in orbit days and orbit semimajor axis columns with null
-- 2. select only important columns from raw data table

create view Planets as
	select Planet_ID, Host_ID, Num_Stars, Discovery_Year, nullif(Orbit_Period, 0) as Orbit_Earth_Days, 
	nullif(Orbit_Axis_AU, 0) as Orbit_SM_Axis_AU, Earth_Radii, Earth_Masses, Eccentricity
    from Planets_raw;
	 
     
# ---------------------------- Queries ----------------------------

-- Though constellations may appear to be made of neighboring stars, they can be extremely far apart.
-- The following query finds each star in the constellation of Leo and its distance from Earth in parsecs.

select Star_ID, Distance_Pc
	from Stars
    where Star_ID like '%leo%';


-- Stars emit light at every wavelength on the electromagnetic spectrum, but the wavelength that is most 
-- abundant gives the star its observed color. Blue stars are the largest and most luminous.
-- The following query identifies all stars that are described as blue.

select Star_ID, H_Class, Temp_K, Chromaticity
    from Stars inner join Harvard_Spectral
    on Stars.H_Class = Harvard_Spectral.Class
		where Chromaticity like '%blue%'
        order by Temp_K desc;
    
    
-- The Harvard Spectral Classification system groups stars (O, B, A, F, G, K, M) based on temperature. 
-- Surface temperature is greatest in O stars and lowest in M stars. This query demonstrates this pattern 
-- using the average temperature of each spectral class.

select Class, avg(Temp_K) as Avg_Temp_K
	from Harvard_Spectral left outer join Stars
		on Harvard_Spectral.Class = Stars.H_Class
    group by Class
    order by Avg_Temp_K desc;
    
    
-- Earth's own star is a yellow main sequence star, which corresponds to the spectral class GV. Such stars
-- may host Earth-like exoplanets. The query below identifies all known exoplanets orbiting such stars within 
-- 20 parsecs of Earth.

select Planet_ID, Distance_Pc, Distance_Pc * 3.26156 as Lightyears
	from Planets inner join Stars
    on Planets.Host_ID = Stars.Star_ID
		where Distance_Pc < 20
        and H_Class = 'G'
        and Y_Class = 'V';


-- While our own solar system revolves around a single star, most systems have two or more stars.
-- This query locates the greatest amount of stars in one system and the exoplanet orbiting the system.

select Planet_ID, Host_ID, Num_Stars
	from Planets
    where Num_Stars = 
		(select max(Num_Stars) from Planets);
        
        
-- Each spectral class O-M has a general range of temperatures that stars are likely to fall within. The
-- query below displays all stars that shine at above average temperature for their class.  

select Star_ID, H_Class, Temp_K
	from Stars as S
	where Temp_K >
		(select avg(Temp_K) from Stars where H_Class = S.H_Class);    
    

-- Rank most common Yerkes star classes and their percentages.

select Lum_Class, Star_Description, count(*) / sum(count(*)) over() as Percent_of_Stars
	from Yerkes_Spectral left outer join Stars
    on Yerkes_Spectral.Lum_Class = Stars.Y_Class
    group by Lum_Class
    order by Percent_of_Stars desc;
    

-- Temperature estimates for each spectral class can vary, particularly for stars in the very early 
-- or late phases of life. This query compares the estimated minimum temperature to the actual minimum 
-- temperature for each class in the dataset.

select Class, Min_Temperature_K, min(Temp_K) as Actual_Min
	from Harvard_Spectral left outer join Stars
    on Harvard_Spectral.Class = Stars.H_Class
		group by H_Class
        order by Min_Temperature_K;


-- Cross-validate Planets/Stars data: select all stars with missing planet data (where Num_of_Planets 
-- and actual count of planets do not match)

select Star_ID, count(Planet_ID) as Count_Planets, Num_of_Planets
	from Stars inner join Planets
    on Stars.Star_ID = Planets.Host_ID
    group by Star_ID
    having Count_Planets != Num_of_Planets;

    

-- Check if dataset is representative: compare the actual percentage of each Harvard class in the dataset 
-- with its expected percentage.

select Class, Chromaticity, Percentage_Main_Sequence as Percent_Est, 
	count(*) / sum(count(*)) over() as Percent_Act
	from Harvard_Spectral left outer join Stars
    on Harvard_Spectral.Class = Stars.H_Class
    group by Class;

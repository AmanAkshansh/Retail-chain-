
libname ex "/folders/myfolders/Case Studies/Case Study 2";

     /*  Importing the Datasets   */

%macro Aman(datafile=,sasfile=);
proc import datafile="/folders/myfolders/Case Studies/Case Study 2/&datafile"
out=ex.&sasfile
dbms=csv
replace;
getnames=yes;
guessingrows=max;
run;
%mend Aman;

%aman(datafile=POS_Q1.csv,sasfile=pos1);
%aman(datafile=POS_Q2.csv,sasfile=pos2);
%aman(datafile=POS_Q3.csv,sasfile=pos3);
%aman(datafile=POS_Q4.csv,sasfile=pos4);
%aman(datafile=Laptops.csv,sasfile=laptops);
%aman(datafile=London_postal_codes.csv,sasfile=customer_location);
%aman(datafile=Store_Locations.csv,sasfile=store_location);



       /*  Data preparation  */
     
%macro abc(dataset);
data ex.&dataset;
retain month;
set ex.&dataset;
drop date;
%mend abc;

%abc(pos1);
%abc(pos2);
%abc(pos3);
%abc(pos4);
/* Date variable is not needed beacuse we have a 'month' variable which is sufficient for
    Time related problems. 

    /* Appending all the POS datasets into a single consolidated file */

proc append base=ex.pos1 data=ex.pos2;
run;
proc append base=ex.pos1 data=ex.pos3;
run;
proc append base=ex.pos1 data=ex.pos4;
run;

   /* 'Configuration' is a categorical variable so changing it to character type */

data ex.pos;
retain month configuration1;
set ex.pos1;
configuration1=put(configuration,3.);
format configuration1 $3.;
drop configuration;
run;

%let dataset=pos4; /* Deleting all the individual POS files */
proc delete data=ex.&dataset;run;

  /* Data preparation for merging all the datasets */
 
 data ex.laptops;
 retain configuration1;
 set ex.laptops;
 configuration1=put(configuration,3.);
 format configuration1 $3.;
 drop configuration;
 run;
 
 data ex.customer_location;
 rename os_x=Customer_x os_y=Customer_y;
 set ex.customer_location;
 run;
 
 data ex.store_location;
 rename os_x=Store_x os_y=Store_y;
 set ex.store_location(drop=lat long);
 run;
 
 /* I forgot to rename the 'postcode' variable in customer location and store location files */
 data ex.customer_location;
 rename postcode=Customer_postcode;
 set ex.customer_location;
 run;
 data ex.store_location;
 rename postcode=Store_postcode;
 set ex.store_location;
 run;
 
 /* Joining all the datasets to create a final datset with all the variables  */
 proc sql;
 create table ex.final_file as
 select a.*,b.*,c.*,d.* from ex.pos as a
 left join ex.laptops as b on a.configuration1=b.configuration1
 left join ex.customer_location as c on a.customer_postcode=c.customer_postcode
 left join ex.store_location as d on a.store_postcode=d.store_postcode
 ;
 quit;
 
/* Checking for missing values in the final datset  */

proc format;
value $miss ' '='Missing' other="Non missing";
value miss .='Missing' other='Non missing';
run;

proc freq data=ex.final_file;
format _char_ $miss. _numeric_ miss.;
table _char_/missing missprint nocum nopercent;
table _numeric_/missing missprint nocum nopercent;
run;

data out;
set ex.final_file;
where store_x is missing;
run;

/* We have missing values in store_x and store_y because one store_postcode - 'S1P 3AU' 
   is not in the store_location dataset   */
  
/* Deleting the 14 observations where retail price is missing  */

data ex.final_file;
set ex.final_file;
if retail_price=. then delete;
run;

/* Creating new variable 'distance' by calculating the euclidean distance between store
postal codes (store_x and store_y) and customer postal codes (customer_x and customer_y)   */

data out;
set ex.final_file;
distance= sqrt(((customer_x-store_x)**2)+((customer_y-store_y)**2));
run;

data ex.final_file;
set out;
distance=round(distance,0.01);
run;

proc freq data=ex.final_file;
format _char_ $miss. _numeric_ miss.;
table _char_/missing missprint nocum nopercent;
table _numeric_/missing missprint nocum nopercent;
run;
/**********************************************************************************************/

                   /*    Data Exploration and Analysis      */
/*                    - - -  - - - - - - - - - - - - - - - - - -  -       */


/*  PRICING:- Which factors are impacting the Prices of laptops   */

    /* (1)  Variation in Prices with time   */
proc format;
value mnth
1="Jan"
2="Feb"
3="Mar"
4="Apr"
5="May"
6="Jun"
7="July"
8="Aug"
9="Sep"
10="Oct"
11="Nov"
12="Dec"
;
run;

/* There are 864 different laptop configurations and it is difficult to observe the variation
   in prices with time for each of the models. Hence  to see the variation on configuration
   level I've selected top 10 models on the basis of their total sales for futher analysis  */

proc sql outobs=10;
create table out as
select configuration1,sum(retail_price) as total_sales
from ex.final_file
group by configuration1
order by total_sales desc;
quit;
/* The dataset 'out' contains the Top 10 laptop configurations. Now we will see the variation 
   in prices with time for these Top 10 laptop models   */
data abc;
set ex.final_file;
where configuration1 in ('296','320','353','207','167','307','347','366','317',' 72');
run;
/* Dataset 'abc' contains all the information for Top 10 configuratons   */

proc tabulate data=abc;
class configuration1 month;
var retail_price;
table month,retail_price*mean;
table configuration1*month,retail_price*mean;
format month mnth.;
label configuration1="Laptop Models" retail_price="Price";
keylabel mean="Average";
run;
/* We have seen the variation in prices with time for Top 10 models. Now we will see this on the 
   overall level  */
ods excel file="/folders/myfolders/Case Studies/Case Study 2/Excel files/file1.xlsx";
proc sql;
select month format=mnth.,avg(retail_price) label=" Average retail price" as avg_price
from ex.final_file
group by month
order by month;
run; 
ods excel close;
/*   Conclusion :- 
(i) On an overall level (across all models) we can clearly see from the reports that prices
  are varying with time. In some months prices are very high while they are very low in some
  months. There is no trend as such,the results are quite random.
  
(ii)  When we saw this variation in prices for Top 10 models we have observed a declining trend,
    with January and Decemeber having the highest and lowest average price respectively.
    
    
    /*  (2) Variation in prices with different retail stores   */
   
   
proc tabulate data=ex.final_file ;
class month store_postcode;
var retail_price;
table month*store_postcode,retail_price*mean;
table store_postcode,retail_price*mean;
format month mnth.;
label store_postcode="Stores";
keylabel mean="Average";
run; 

ods excel file= "/folders/myfolders/Case Studies/Case Study 2/Excel files/file2.xlsx";
proc sql;
select store_postcode label="Stores",avg(retail_price) label="Average price" as avg_price
from ex.final_file
group by store_postcode
order by avg_price desc;
quit;
ods excel close;

/* After observing the average price for all retail outlets at an overall level and for each 
   month we can easily conclude that prices are pretty much consistent across all the stores 
   except some stores(CR7 8LE,E7 8NW,N3 1DH,SW1P 3AU and W4 3PH) which are offering discounts
   on the Laptop prices  */
  
/* Relation between Average price and Total sales of the stores  */

ods excel file="/folders/myfolders/Case Studies/Case Study 2/Excel files/file3.xlsx";
proc sql;
title "Relationship between Average price and Total sales";
select store_postcode label="Stores",avg(retail_price) label="Average price" as avg_price,
sum(retail_price) label="Total sales" as tot_sales
from ex.final_file
group by store_postcode
order by avg_price desc;
quit;
ods excel close;

/* So from the report we can conclude that it is not neccessary that the stores with lower
   Average pricing do sell more than the others. But yes there is one store (SW1P 3AU) with
   relatively lower average pricing that has recorded the highest sales.   */
  
  
        /*  (3) Effect of configuration on Laptop prices   */
 
 /* For this we again take the Top 10 configurations on the basis of their total sales and 
    then try to find their relationship with the prices. */
   
proc tabulate data= ex.final_file;
where configuration1 in ('296','320','353','207','167','307','347','366','317',' 72');
class configuration1 month;
var retail_price;
table month*configuration1,retail_price*(var range);
table configuration1,retail_price*(var range);
format month mnth.;
label configuration1="Configurations" retail_price="Price";
keylabel var="Variation in price" range="Range of price";
run; 

/* Hence after going through the reports at both overall and monthly level we can say that 
prices are affected by the laptop's configuration. The variation in price and the range of price
is different for each configuration. 




           /*  LOCATION - How does location influence the sales   */
 
   
 /* (1) How far do customers travel to buy their laptops ?  */
 
 ods excel file="/folders/myfolders/Case Studies/Case Study 2/Excel files/file2.xlsx";
 proc sql;
 select store_postcode label="Stores",avg(distance) label="Distance travelled by customers"
 as dst
 from ex.final_file
 where store_postcode ne 'S1P 3AU'
 group by store_postcode
 order by dst desc;
 quit;
 ods excel close;
 
 
 /* (2) Relationship between store proximity to the customers and the sales at the stores  */
 
proc sql;
create table out as
select store_postcode label="Stores",avg(distance) label="Distance travelled by customers"
as dst,count(customer_postcode) label="Total customers vising the store" as tot_cust,
sum(retail_price) label="Total sales" as tot_sales
from ex.final_file
where store_postcode ne 'S1P 3AU'
group by store_postcode
order by dst;
quit;

proc print data=out sumlabel="Total sum";
sum tot_sales;
run;
/* Total sales across all the stores(except S1P 3AU) = 149156844.5   */

data out;
set out;
pct_sales= (tot_sales/149156844.5);
cum_pct_sales+pct_sales;
format pct_sales percent9.2 cum_pct_sales percent9.2;
run;

ods excel file="/folders/myfolders/Case Studies/Case Study 2/Excel files/file3.xlsx";
proc print data=out split="*";
label store_postcode="Stores" dst="Distance travelled by*customers to reach the store"
      tot_cust="Total customers*visiting the store" tot_sales="Total sales"
      pct_sales="Percent of sales" cum_pct_sales="Cumulative sales percentage";
run;
ods excel close;
/* CONCLUSION :- 

(i) The reports clearly suggest that store proximity to customers plays a vital role in the
sales of the stores.

(ii) More than 60% of the total sales is contributed by only the 6 stores which are closest 
to the customers.                                                                            */



                 /*   OTHER QUESTIONS    */
 
 /* (1) Stores and their sales revenue and sales volume   */ 

proc sql;
create table out as                 
select store_postcode label="Stores" as store,
sum(retail_price) label="Total sales" as tot_sales
from  ex.final_file
group by store
order by tot_sales desc;
quit; 

proc print data=out;
sum tot_sales;
run;
/* Total sales across all the stores = 149232080.5  */

data out;
set out;
pct_sales=(tot_sales/149232080.5);
cum_pct_sales+pct_sales;
format pct_sales percent9.2 cum_pct_sales percent9.2; 
run;

proc print data=out split="*";
label store_postcode="Stores" tot_sales="Total sales"
      pct_sales="Percent of sales" cum_pct_sales="Cumulative sales*percentage";
run;
/* About 71% of the total sales is accounted for by only 5 stores.    */


  /*  Relationship between sales revenue and sales volume   */
 
 proc sql;
 create table out as
 select store_postcode label="Stores",
 sum(retail_price) label="Total Sales" as tot_sales,
 count(*) label="Total no. of sales" as tot_no_sales
 from ex.final_file
 group by store_postcode
 order by tot_sales desc;
 quit;
 /* Each row in the final file represents a unique transaction.
    Hence Total number of sales across all the stores=297558
    We already know that Total sales across all the stores=149232080.5   */
   
data out;
set out;
pct_sales=(tot_sales/149232080.5);
pct_no_sales=(tot_no_sales/297558); 
cum_pct_sales+pct_sales;
cum_pct_no_sales+pct_no_sales;
format pct_sales percent10.2 pct_no_sales percent10.2 
       cum_pct_sales percent10.2 cum_pct_no_sales percent10.2;
run; 

ods excel file="/folders/myfolders/Case Studies/Case Study 2/Excel files/file2.xlsx";
proc print data=out split="*";
label
tot_sales="Sales revenue"
tot_no_sales="Sales volume"
pct_sales="Sales revenue %"
pct_no_sales="Sales volume %"
cum_pct_sales="Cumulative sales*revenue %"
cum_pct_no_sales="Cumulative sales*volume %"
;
run;
ods excel close;

/* CONCLUSION :-
(1) There is a direct relationship between sales revenue and sales volume. Both are following
     the same trend.
     
(2) The sales revenue and sales volume are mostly concentrated in a few stores        */


    /* (2) Effect of different configuration features on the prices of laptops   */

/* Creating buckets/groups for all the configuration features   */

data abc;
set ex.final_file;
drop month customer_postcode customer_x customer_y store_x store_y distance;
run;

data out;
retain configuration1 store_postcode retail_price;
length screen_size $4. battery_life $4.  Processor_speed $4. HD_size $6.; 
set abc;
if Screen_Size__Inches_ =15 then screen_size="Low";
else screen_size="High";
if Battery_Life__Hours_ =4 then battery_life="Low";
else battery_life="High";
if RAM__GB_ =4 then RAM="High";
else RAM="Low";
if Processor_Speeds__GHz_ =1.5 then Processor_speed="Low";
else processor_speed="High";
if HD_Size__GB_= 40 then HD_size="Low";
else if HD_size__GB_ in (80,120) then HD_size="Medium";
else HD_size="High";
drop Screen_Size__Inches_ Battery_Life__Hours_ RAM__GB_
     Processor_Speeds__GHz_ HD_Size__GB_;
run;

data ex.cnfg_grp;
set out;
run;

ods excel file="/folders/myfolders/Case Studies/Case Study 2/Excel files/file2.xlsx";
proc sql;
select screen_size label="Screen size(in inches)",
battery_life label="Battery life(in hours)",
RAM,processor_speed label="Processor speed(In GHz)",
HD_size label="HD size(in GB)",
integrated_wireless_ label="Integrated wireless",
bundled_applications_ label="Bundled applications",
avg(retail_price) label="Average price" as avg_price
from ex.cnfg_grp
group by screen_size,battery_life,RAM,processor_speed,HD_size,
         bundled_applications_,integrated_wireless_
order by avg_price desc;
quit;         
ods excel close;

 /*  CONCLUSION :-

(1) All features including screen size,Battery life,RAM,Processor speeds,Integrated wireless,
    HD size and Bundled applications are influencing the prices.
    
(2) Prices are correlated positively with configuration,i.e., Increased configuration has a
    positive influence on the pricing of the laptops.     


/**++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/


         
































   
   
   
   
   
   
   
   
 

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 







 

            
                















 
 
   

 
 
  
  
  
  












  




  
   
   
    
    
    
      

  



 


















  
  
  







 
 
 
 
 
 
 























 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 





























  
















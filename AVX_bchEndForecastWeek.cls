global class AVX_bchEndForecastWeek implements Database.Batchable<sObject> {
	
	global String query = '';
	
	global AVX_bchEndForecastWeek() {

		this.query = 'SELECT ID, Name, IsCurrentWeek__c, ForecastPlanting__c, Week__c, ForecastCulture__c';
		this.query += ' FROM ForecastWeek__c';
		this.query += ' WHERE IsCurrentWeek__c = true';

		System.debug(this.query);
		
	}
	
	global Database.QueryLocator start(Database.BatchableContext BC) {
		return Database.getQueryLocator(this.query);
	}

   	global void execute(Database.BatchableContext BC, List<ForecastWeek__c> scope) {

   		List<ForecastWeek__c> lstUpsertWeek = new List<ForecastWeek__c>();
		
		for(ForecastWeek__c week: scope){

			//NOVA SEMANA
			ForecastWeek__c newWeek		= week.Clone(false, false, false, false);
			newWeek.Week__c 			= date.Today().addDays(4);
			newWeek.IsCurrentWeek__c	= true;
			lstUpsertWeek.add(newWeek);

			//SEMANA ANTERIOR
			week.IsCurrentWeek__c 		= false;
			week.ForecastPlanting__c 	= null;

			lstUpsertWeek.add(week);
		}

		upsert lstUpsertWeek;
	}
	
	global void finish(Database.BatchableContext BC) {
		
	}
	
}
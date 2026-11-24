import {HttpsError} from 'firebase-functions/v2/https';
export function requireTransportSchedule(type,scheduledAt,appointment){
 const start=appointment.startsAt?.toMillis?.(),end=appointment.endsAt?.toMillis?.(),at=Date.parse(scheduledAt);
 if(!Number.isFinite(start)||!Number.isFinite(end)||!Number.isFinite(at))throw new HttpsError('failed-precondition','Revise os horários do atendimento antes de programar o transporte.');
 if(type==='PICKUP'&&at>=start)throw new HttpsError('invalid-argument','A coleta deve ocorrer antes do atendimento.');
 if(type==='RETURN'&&at<end)throw new HttpsError('invalid-argument','O retorno deve ocorrer a partir do término previsto do atendimento.');
}

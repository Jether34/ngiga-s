"""Laboratory inventory API. SQLite transactions are the source of truth."""
import os, sqlite3, uuid, asyncio, re
from dotenv import load_dotenv
from datetime import datetime, timezone, timedelta
from typing import Optional
from fastapi import FastAPI, Depends, HTTPException, WebSocket, WebSocketDisconnect, Header
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field, field_validator
from jose import jwt, JWTError
from passlib.context import CryptContext

load_dotenv()
DB=os.getenv('DATABASE_PATH','./laboratory.db'); SECRET=os.getenv('SECRET_KEY',''); ALG='HS256'
if len(SECRET)<32 or len(os.getenv('ADMIN_PASSWORD',''))<12:
 raise RuntimeError('Set a SECRET_KEY of at least 32 characters and ADMIN_PASSWORD of at least 12 characters in backend/.env')
pwd=CryptContext(schemes=['bcrypt'], deprecated='auto'); app=FastAPI(title='Laboratory Inventory API',version='1.0.0')
app.add_middleware(CORSMiddleware,allow_origins=['*'],allow_methods=['*'],allow_headers=['*'])
def db():
 c=sqlite3.connect(DB,timeout=15); c.row_factory=sqlite3.Row; c.execute('PRAGMA foreign_keys=ON'); return c
def init():
 c=db(); c.executescript('''
 CREATE TABLE IF NOT EXISTS users(id TEXT PRIMARY KEY,email TEXT UNIQUE NOT NULL,password_hash TEXT NOT NULL,name TEXT NOT NULL,account_id TEXT UNIQUE NOT NULL,role TEXT NOT NULL CHECK(role IN ('ADMIN','STUDENT','FACULTY','USER')));
 CREATE UNIQUE INDEX IF NOT EXISTS users_email_ci ON users(lower(email));
 CREATE TABLE IF NOT EXISTS equipment(id TEXT PRIMARY KEY,name TEXT NOT NULL,category TEXT NOT NULL,min_stock INTEGER NOT NULL DEFAULT 0);
 CREATE TABLE IF NOT EXISTS units(id TEXT PRIMARY KEY,equipment_id TEXT NOT NULL REFERENCES equipment(id),serial TEXT UNIQUE NOT NULL,status TEXT NOT NULL CHECK(status IN ('AVAILABLE','ISSUED','MAINTENANCE')));
 CREATE TABLE IF NOT EXISTS loans(id TEXT PRIMARY KEY,user_id TEXT NOT NULL REFERENCES users(id),unit_id TEXT NOT NULL REFERENCES units(id),borrowed_at TEXT NOT NULL,due_at TEXT NOT NULL,returned_at TEXT,status TEXT NOT NULL CHECK(status IN ('ACTIVE','RETURNED','OVERDUE')));
 CREATE UNIQUE INDEX IF NOT EXISTS one_active_loan_per_unit ON loans(unit_id) WHERE status IN ('ACTIVE','OVERDUE');
 CREATE TABLE IF NOT EXISTS transactions(id TEXT PRIMARY KEY,equipment_id TEXT NOT NULL REFERENCES equipment(id),unit_id TEXT REFERENCES units(id),loan_id TEXT REFERENCES loans(id),type TEXT NOT NULL CHECK(type IN ('RECEIVE','ISSUE')),quantity INTEGER NOT NULL CHECK(quantity>0),created_at TEXT NOT NULL,actor_id TEXT NOT NULL REFERENCES users(id),idempotency_key TEXT UNIQUE);
 CREATE TABLE IF NOT EXISTS receipts(loan_id TEXT PRIMARY KEY REFERENCES loans(id),receipt_number TEXT UNIQUE NOT NULL,created_at TEXT NOT NULL);
 CREATE TABLE IF NOT EXISTS user_profiles(user_id TEXT PRIMARY KEY REFERENCES users(id),phone TEXT UNIQUE,year_level TEXT,program TEXT,home_address TEXT);
 ''')
 if not c.execute('select 1 from users').fetchone():
  c.execute('insert into users values(?,?,?,?,?,?)',('admin-1',os.getenv('ADMIN_EMAIL','admin@example.edu'),pwd.hash(os.getenv('ADMIN_PASSWORD')),os.getenv('ADMIN_NAME','Laboratory Administrator'),os.getenv('ADMIN_ID','ADMIN-001'),'ADMIN'))
  c.execute('insert into users values(?,?,?,?,?,?)',('student-1','student@example.edu',pwd.hash('student123'),'Alex Student','STU-2024001','STUDENT'))
  for e in [('EQ-001','Digital Multimeter','Measurement',2),('EQ-002','Oscilloscope','Test Equipment',1),('EQ-003','Soldering Station','Workshop',1)]: c.execute('insert into equipment values(?,?,?,?)',e)
  for i in range(1,4): c.execute('insert into units values(?,?,?,?)',(f'unit-{i}','EQ-001',f'DMM-{1000+i}','AVAILABLE'))
  for i in range(1,3): c.execute('insert into units values(?,?,?,?)',(f'unit-o-{i}','EQ-002',f'SCOPE-{2000+i}','AVAILABLE'))
  c.execute('insert into units values(?,?,?,?)',('unit-s-1','EQ-003','SOLDER-3001','AVAILABLE'))
 c.commit(); c.close()
init()
class Login(BaseModel): email:Optional[str]=None; phone:Optional[str]=None; password:str
class Signup(BaseModel):
 name:str=Field(min_length=2,max_length=100); email:str=Field(min_length=6,max_length=254); account_id:str=Field(min_length=3,max_length=64); password:str=Field(min_length=12,max_length=72)
 phone:Optional[str]=None; year_level:Optional[str]=None; program:Optional[str]=None; home_address:Optional[str]=None
 @field_validator('name')
 @classmethod
 def clean_name(cls,v):
  v=v.strip()
  if len(v)<2: raise ValueError('Enter your full name')
  return v
 @field_validator('email')
 @classmethod
 def clean_email(cls,v):
  v=v.strip().lower()
  if not re.fullmatch(r'[^@\s]+@[^@\s]+\.[^@\s]+',v): raise ValueError('Enter a valid email address')
  return v
 @field_validator('account_id')
 @classmethod
 def clean_account_id(cls,v):
  v=v.strip()
  if not re.fullmatch(r'[A-Za-z0-9_-]{3,64}',v): raise ValueError('Use 3-64 letters, numbers, hyphens, or underscores for your student ID')
  return v
class LoanRequest(BaseModel): unit_id:str; due_at:datetime; idempotency_key:str=Field(default_factory=lambda:str(uuid.uuid4()))
class EquipmentIn(BaseModel): id:str=Field(min_length=1,max_length=64); name:str=Field(min_length=1,max_length=160); category:str=Field(min_length=1,max_length=100); min_stock:int=Field(ge=0); serials:list[str]=[]; initial_quantity:int=Field(default=0,ge=0)
class EquipmentUpdate(BaseModel): name:Optional[str]=None; category:Optional[str]=None; min_stock:Optional[int]=Field(default=None,ge=0)
class UnitIn(BaseModel): serial:str=Field(min_length=1,max_length=160)
class UnitStatus(BaseModel): status:str
class TxIn(BaseModel): equipment_id:str; type:str; quantity:int=Field(gt=0); idempotency_key:str
def current(authorization:Optional[str]=Header(None)):
 if not authorization or not authorization.startswith('Bearer '): raise HTTPException(401,'Sign in required')
 try: uid=jwt.decode(authorization[7:],SECRET,algorithms=[ALG])['sub']
 except JWTError: raise HTTPException(401,'Session expired')
 c=db(); u=c.execute('select id,email,name,account_id,role from users where id=?',(uid,)).fetchone(); c.close()
 if not u: raise HTTPException(401,'Session expired')
 return dict(u)
def admin(u=Depends(current)):
 if u['role']!='ADMIN': raise HTTPException(403,'Administrator access required')
 return u
class Events:
 def __init__(self): self.sockets=[]
 async def send(self,event):
  for s in list(self.sockets):
   try: await s.send_json(event)
   except: self.sockets.remove(s)
events=Events()
@app.post('/auth/signup',status_code=201)
def signup(x:Signup):
 c=db(); uid=str(uuid.uuid4())
 try:
  with c:
   c.execute('insert into users(id,email,password_hash,name,account_id,role) values(?,?,?,?,?,?)',(uid,x.email,pwd.hash(x.password),x.name,x.account_id,'STUDENT'))
   c.execute('insert into user_profiles(user_id,phone,year_level,program,home_address) values(?,?,?,?,?)',(uid,x.phone.strip() if x.phone else None,x.year_level,x.program,x.home_address))
 except sqlite3.IntegrityError: c.close(); raise HTTPException(409,'That email, phone, or student ID is already registered')
 c.close(); return {'message':'Student account created. Sign in to continue.','account_id':x.account_id,'role':'STUDENT'}
@app.post('/auth/login')
def login(x:Login):
 if not x.email and not x.phone: raise HTTPException(422,'Enter your email or phone number')
 c=db()
 if x.phone:
  u=c.execute('select users.* from users join user_profiles on users.id=user_profiles.user_id where user_profiles.phone=?',(x.phone.strip(),)).fetchone()
 else:
  u=c.execute('select * from users where lower(email)=lower(?)',(x.email,)).fetchone()
 c.close()
 if not u or not pwd.verify(x.password,u['password_hash']): raise HTTPException(401,'Email or password is incorrect')
 token=jwt.encode({'sub':u['id'],'exp':datetime.now(timezone.utc)+timedelta(hours=12)},SECRET,algorithm=ALG)
 return {'token':token,'user':{'id':u['id'],'email':u['email'],'name':u['name'],'account_id':u['account_id'],'role':u['role']}}
@app.get('/me')
def me(u=Depends(current)): return u
def inventory_row(c,e):
 r=dict(e); q=c.execute('select count(*) total,sum(case when status="AVAILABLE" then 1 else 0 end) available,sum(case when status="ISSUED" then 1 else 0 end) issued,sum(case when status="MAINTENANCE" then 1 else 0 end) maintenance from units where equipment_id=?',(e['id'],)).fetchone(); r.update(total=q['total'] or 0,available=q['available'] or 0,issued=q['issued'] or 0,maintenance=q['maintenance'] or 0); return r
@app.get('/equipment')
def equipment(u=Depends(current)):
 c=db(); rows=[inventory_row(c,e) for e in c.execute('select * from equipment order by name collate nocase')]; c.close(); return rows
@app.get('/equipment/{equipment_id}')
def equipment_detail(equipment_id:str,u=Depends(current)):
 c=db(); e=c.execute('select * from equipment where id=?',(equipment_id,)).fetchone()
 if not e: c.close(); raise HTTPException(404,'Product not found')
 result=inventory_row(c,e); result['units']=[dict(x) for x in c.execute('select id,serial,status from units where equipment_id=? order by serial',(equipment_id,))]; c.close(); return result
@app.get('/units/{barcode}')
def unit_by_barcode(barcode:str,u=Depends(current)):
 c=db(); row=c.execute('select u.id unit_id,u.serial,u.status,e.id equipment_id,e.name equipment_name,e.category from units u join equipment e on e.id=u.equipment_id where u.serial=?',(barcode,)).fetchone(); c.close()
 if not row: raise HTTPException(404,'Scanned barcode was not found')
 return dict(row)
@app.post('/equipment/{equipment_id}/units',status_code=201)
async def add_unit(equipment_id:str,x:UnitIn,u=Depends(admin)):
 serial=x.serial.strip()
 if not serial: raise HTTPException(422,'Serial/barcode cannot be blank')
 c=db(); unit_id=str(uuid.uuid4())
 try:
  with c:
   if not c.execute('select 1 from equipment where id=?',(equipment_id,)).fetchone(): raise HTTPException(404,'Product not found')
   c.execute('insert into units values(?,?,?,?)',(unit_id,equipment_id,serial,'AVAILABLE'))
   c.execute('insert into transactions values(?,?,?,?,?,?,?,?,?)',(str(uuid.uuid4()),equipment_id,unit_id,None,'RECEIVE',1,datetime.now(timezone.utc).isoformat(),u['id'],'unit-receive-'+unit_id))
 except sqlite3.IntegrityError:
  c.close(); raise HTTPException(409,'This serial/barcode is already registered')
 result={'id':unit_id,'equipment_id':equipment_id,'serial':serial,'status':'AVAILABLE'}
 await events.send({'type':'transaction','data':{'equipment_id':equipment_id,'type':'RECEIVE','quantity':1,'serial':serial}})
 await events.send({'type':'inventory','data':result}); c.close(); return result
@app.post('/equipment')
def add_equipment(x:EquipmentIn,u=Depends(admin)):
 c=db()
 try:
  serials=x.serials or [f'{x.id}-{uuid.uuid4().hex[:8].upper()}' for _ in range(x.initial_quantity)]
  if x.serials and x.initial_quantity not in (0,len(x.serials)): raise HTTPException(422,'Initial quantity must match the provided barcode count')
  equipment_id=x.id.strip()
  with c: c.execute('insert into equipment(id,name,category,min_stock) values(?,?,?,?)',(equipment_id,x.name.strip(),x.category.strip(),x.min_stock)); c.executemany('insert into units values(?,?,?,?)',[(str(uuid.uuid4()),equipment_id,s.strip(),'AVAILABLE') for s in serials])
 except sqlite3.IntegrityError as e: c.close(); raise HTTPException(409,str(e))
 r=inventory_row(c,c.execute('select * from equipment where id=?',(equipment_id,)).fetchone()); c.close(); return r
@app.patch('/equipment/{equipment_id}')
def update_equipment(equipment_id:str,x:EquipmentUpdate,u=Depends(admin)):
 changes={k:v.strip() if isinstance(v,str) else v for k,v in x.model_dump(exclude_unset=True).items()}
 if any(v=='' for v in changes.values() if isinstance(v,str)): raise HTTPException(422,'Product fields cannot be blank')
 if not changes: raise HTTPException(422,'No changes were supplied')
 c=db(); row=c.execute('select * from equipment where id=?',(equipment_id,)).fetchone()
 if not row: c.close(); raise HTTPException(404,'Product not found')
 with c: c.execute('update equipment set '+','.join(f'{k}=?' for k in changes)+' where id=?',(*changes.values(),equipment_id))
 result=inventory_row(c,c.execute('select * from equipment where id=?',(equipment_id,)).fetchone()); c.close(); return result
@app.delete('/equipment/{equipment_id}')
def delete_equipment(equipment_id:str,u=Depends(admin)):
 c=db(); row=c.execute('select id from equipment where id=?',(equipment_id,)).fetchone()
 if not row: c.close(); raise HTTPException(404,'Product not found')
 if c.execute('select 1 from transactions where equipment_id=? limit 1',(equipment_id,)).fetchone(): c.close(); raise HTTPException(409,'Products with transaction history cannot be deleted; change their units to maintenance instead')
 with c: c.execute('delete from units where equipment_id=?',(equipment_id,)); c.execute('delete from equipment where id=?',(equipment_id,))
 c.close(); return {'deleted':equipment_id}
@app.patch('/units/{unit_id}/status')
async def set_unit_status(unit_id:str,x:UnitStatus,u=Depends(admin)):
 if x.status not in ('AVAILABLE','MAINTENANCE'): raise HTTPException(422,'Set a unit to AVAILABLE or MAINTENANCE; active loans control ISSUED status')
 c=db(); unit=c.execute('select * from units where id=?',(unit_id,)).fetchone()
 if not unit: c.close(); raise HTTPException(404,'Unit not found')
 if unit['status']=='ISSUED': c.close(); raise HTTPException(409,'An issued unit can only be made available by completing its return')
 with c: c.execute('update units set status=? where id=?',(x.status,unit_id))
 c.close(); result={'id':unit_id,'status':x.status}; await events.send({'type':'inventory','data':result}); return result
@app.post('/transactions')
async def transaction(x:TxIn,u=Depends(admin)):
 if x.type not in ('RECEIVE','ISSUE'): raise HTTPException(422,'Type must be RECEIVE or ISSUE')
 c=db()
 try:
  with c:
   prev=c.execute('select * from transactions where idempotency_key=?',(x.idempotency_key,)).fetchone()
   if prev: return dict(prev)
   eq=c.execute('select id from equipment where id=?',(x.equipment_id,)).fetchone()
   if not eq: raise HTTPException(404,'Equipment not found')
   if x.type=='RECEIVE':
    for _ in range(x.quantity): c.execute('insert into units values(?,?,?,?)',(str(uuid.uuid4()),x.equipment_id,'MANUAL-'+str(uuid.uuid4()),'AVAILABLE'))
   else:
    units=c.execute('select id from units where equipment_id=? and status="AVAILABLE" limit ?',(x.equipment_id,x.quantity)).fetchall()
    if len(units)<x.quantity: raise HTTPException(409,'Insufficient available units')
    c.executemany('update units set status="ISSUED" where id=?',[(z['id'],) for z in units])
   tid=str(uuid.uuid4()); now=datetime.now(timezone.utc).isoformat(); c.execute('insert into transactions values(?,?,?,?,?,?,?,?,?)',(tid,x.equipment_id,None,None,x.type,x.quantity,now,u['id'],x.idempotency_key))
 except sqlite3.IntegrityError as e: c.close(); raise HTTPException(409,str(e))
 tx=dict(c.execute('select * from transactions where id=?',(tid,)).fetchone()); c.close(); await events.send({'type':'transaction','data':tx}); return tx
@app.post('/loans')
async def borrow(x:LoanRequest,u=Depends(current)):
 if x.due_at.tzinfo is None or x.due_at<=datetime.now(timezone.utc): raise HTTPException(422,'Return date must be in the future and include timezone')
 c=db(); now=datetime.now(timezone.utc).isoformat(); lid=str(uuid.uuid4())
 try:
  with c:
   prior=c.execute('select loan_id from transactions where idempotency_key=?',(x.idempotency_key,)).fetchone()
   if prior:
    result=receipt(c,prior['loan_id']); return result
   unit=c.execute('select u.*,e.name equipment_name,e.id equipment_id from units u join equipment e on e.id=u.equipment_id where u.id=?',(x.unit_id,)).fetchone()
   if not unit: raise HTTPException(404,'Scanned item was not found')
   if unit['status']!='AVAILABLE': raise HTTPException(409,'This unit is not available')
   c.execute('update units set status="ISSUED" where id=? and status="AVAILABLE"',(x.unit_id,))
   if c.execute('select changes()').fetchone()[0]!=1: raise HTTPException(409,'This unit was just borrowed by another user')
   c.execute('insert into loans values(?,?,?,?,?,?,?)',(lid,u['id'],x.unit_id,now,x.due_at.astimezone(timezone.utc).isoformat(),None,'ACTIVE'))
   c.execute('insert into receipts values(?,?,?)',(lid,'LOAN-'+lid[:8].upper(),now))
   c.execute('insert into transactions values(?,?,?,?,?,?,?,?,?)',(str(uuid.uuid4()),unit['equipment_id'],x.unit_id,lid,'ISSUE',1,now,u['id'],x.idempotency_key))
   result=receipt(c,lid)
 except sqlite3.IntegrityError as e: c.close(); raise HTTPException(409,'Unit already has an active loan')
 c.close(); await events.send({'type':'loan','data':result}); return result
def receipt(c,lid):
 return dict(c.execute('''select l.id loan_id,r.receipt_number,l.borrowed_at,l.due_at,l.returned_at,case when l.status='ACTIVE' and l.due_at < ? then 'OVERDUE' else l.status end loan_status,u.id unit_record_id,u.serial barcode,u.equipment_id,e.name equipment_name,usr.name borrower_name,usr.account_id borrower_id,usr.role account_type,usr.email from loans l join receipts r on r.loan_id=l.id join units u on u.id=l.unit_id join equipment e on e.id=u.equipment_id join users usr on usr.id=l.user_id where l.id=?''',(datetime.now(timezone.utc).isoformat(),lid)).fetchone())
@app.post('/returns/{barcode}')
async def return_unit(barcode:str,u=Depends(current)):
 c=db(); now=datetime.now(timezone.utc).isoformat()
 with c:
  unit=c.execute('select * from units where serial=?',(barcode,)).fetchone()
  if not unit: raise HTTPException(404,'Scanned item was not found')
  loan=c.execute('select * from loans where unit_id=? and status in ("ACTIVE","OVERDUE")',(unit['id'],)).fetchone()
  if not loan: raise HTTPException(409,'This unit has no active loan')
  if u['role']!='ADMIN' and loan['user_id']!=u['id']: raise HTTPException(403,'Only the borrower or an administrator can return this unit')
  c.execute('update loans set status="RETURNED",returned_at=? where id=?',(now,loan['id'])); c.execute('update units set status="AVAILABLE" where id=?',(unit['id'],))
  c.execute('insert into transactions values(?,?,?,?,?,?,?,?,?)',(str(uuid.uuid4()),unit['equipment_id'],unit['id'],loan['id'],'RECEIVE',1,now,u['id'],'return-'+loan['id']))
  result=receipt(c,loan['id'])
 c.close(); await events.send({'type':'return','data':result}); return result
@app.get('/receipts')
def receipts(u=Depends(current)):
 c=db(); sql='select id from loans'+('' if u['role']=='ADMIN' else ' where user_id=?')+' order by borrowed_at desc'; rows=c.execute(sql,() if u['role']=='ADMIN' else (u['id'],)).fetchall(); out=[receipt(c,x['id']) for x in rows]; c.close(); return out
@app.get('/transactions')
def history(equipment_id:Optional[str]=None,type:Optional[str]=None,u=Depends(admin)):
 c=db(); sql='select t.*,e.name equipment_name,u.serial from transactions t join equipment e on e.id=t.equipment_id left join units u on u.id=t.unit_id where 1=1'; args=[]
 if equipment_id: sql+=' and t.equipment_id=?'; args.append(equipment_id)
 if type: sql+=' and t.type=?'; args.append(type)
 rows=[dict(r) for r in c.execute(sql+' order by t.created_at desc',args)]; c.close(); return rows
@app.get('/reports/low-stock')
def low(u=Depends(admin)):
 return [x for x in equipment(u) if x['available']<=x['min_stock']]
@app.websocket('/events')
async def websocket(ws:WebSocket,token:str=''):
 try:
  data=jwt.decode(token,SECRET,algorithms=[ALG]); c=db(); user=c.execute('select role from users where id=?',(data['sub'],)).fetchone(); c.close()
  if not user or user['role']!='ADMIN': await ws.close(code=4403); return
 except: await ws.close(code=4401); return
 await ws.accept(); events.sockets.append(ws)
 try:
  while True: await ws.receive_text()
 except WebSocketDisconnect:
  if ws in events.sockets: events.sockets.remove(ws)

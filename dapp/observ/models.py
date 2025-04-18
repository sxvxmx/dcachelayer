from sqlalchemy import Column, Integer, String, DateTime
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
import datetime

Base = declarative_base()

class File(Base):
    """Simple file in database declaration via sqlite"""
    __tablename__ = 'files'
    id = Column(Integer, primary_key=True)
    path = Column(String, nullable=False)
    storage = Column(String, nullable=False)
    size = Column(Integer)
    upload_time = Column(DateTime, default=datetime.datetime.utcnow)

engine = create_engine('sqlite:///files.db')
Session = sessionmaker(bind=engine)

def init_db():
    Base.metadata.create_all(engine)
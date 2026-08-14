from pydantic import BaseModel


class ContentProcessRequest(BaseModel):
    extracted_text: str
    document_name: str
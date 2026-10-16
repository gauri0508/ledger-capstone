from datetime import date, datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field

CATEGORIES = ("food", "transport", "rent", "utilities", "shopping", "health", "fun", "other")


class ExpenseIn(BaseModel):
    amount: Decimal = Field(gt=0, le=Decimal("99999999.99"), decimal_places=2, examples=[249.50])
    category: str = Field(min_length=1, max_length=50, examples=["food"])
    note: str | None = Field(default=None, max_length=255, examples=["lunch with team"])
    spent_on: date = Field(default_factory=date.today)


class ExpenseOut(ExpenseIn):
    model_config = ConfigDict(from_attributes=True)

    id: int
    created_at: datetime


class CategoryTotal(BaseModel):
    category: str
    total: Decimal
    count: int


class Summary(BaseModel):
    total: Decimal
    count: int
    month: str
    month_total: Decimal
    top_category: str | None
    by_category: list[CategoryTotal]

from datetime import date
from decimal import Decimal

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.db import get_db
from app.models import Expense
from app.schemas import CategoryTotal, ExpenseIn, ExpenseOut, Summary

router = APIRouter(prefix="/api/expenses", tags=["expenses"])


def _get_or_404(db: Session, expense_id: int) -> Expense:
    expense = db.get(Expense, expense_id)
    if expense is None:
        raise HTTPException(status_code=404, detail=f"expense {expense_id} not found")
    return expense


@router.get("", response_model=list[ExpenseOut])
def list_expenses(
    category: str | None = Query(default=None, description="filter by category"),
    db: Session = Depends(get_db),
):
    stmt = select(Expense).order_by(Expense.spent_on.desc(), Expense.id.desc())
    if category:
        stmt = stmt.where(Expense.category == category)
    return db.scalars(stmt).all()


# /summary is registered before /{expense_id}; otherwise "summary" would be parsed as an id.
@router.get("/summary", response_model=Summary)
def summary(db: Session = Depends(get_db)):
    total, count = db.execute(select(func.coalesce(func.sum(Expense.amount), 0), func.count(Expense.id))).one()

    today = date.today()
    month_start = today.replace(day=1)
    month_total = db.scalar(
        select(func.coalesce(func.sum(Expense.amount), 0)).where(Expense.spent_on >= month_start)
    )

    rows = db.execute(
        select(Expense.category, func.sum(Expense.amount), func.count(Expense.id))
        .group_by(Expense.category)
        .order_by(func.sum(Expense.amount).desc())
    ).all()
    by_category = [CategoryTotal(category=c, total=Decimal(t), count=n) for c, t, n in rows]

    return Summary(
        total=Decimal(total),
        count=count,
        month=today.strftime("%Y-%m"),
        month_total=Decimal(month_total),
        top_category=by_category[0].category if by_category else None,
        by_category=by_category,
    )


@router.get("/{expense_id}", response_model=ExpenseOut)
def get_expense(expense_id: int, db: Session = Depends(get_db)):
    return _get_or_404(db, expense_id)


@router.post("", response_model=ExpenseOut, status_code=status.HTTP_201_CREATED)
def create_expense(payload: ExpenseIn, db: Session = Depends(get_db)):
    expense = Expense(**payload.model_dump())
    db.add(expense)
    db.commit()
    db.refresh(expense)
    return expense


@router.put("/{expense_id}", response_model=ExpenseOut)
def update_expense(expense_id: int, payload: ExpenseIn, db: Session = Depends(get_db)):
    expense = _get_or_404(db, expense_id)
    for key, value in payload.model_dump().items():
        setattr(expense, key, value)
    db.commit()
    db.refresh(expense)
    return expense


@router.delete("/{expense_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_expense(expense_id: int, db: Session = Depends(get_db)):
    expense = _get_or_404(db, expense_id)
    db.delete(expense)
    db.commit()
    return None

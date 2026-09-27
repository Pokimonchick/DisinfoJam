class_name NewsroomBalance
extends Resource

@export_group("Цель кампании")
@export_range(1, 100, 1) var campaign_days: int = 5
# Legacy save/resource field; the chapter ends after the required shifts.
@export_range(0, 100000, 5) var campaign_money: int = 200

@export_group("Смена")
@export_range(5.0, 600.0) var shift_seconds: float = 180.0
@export_range(1, 100, 1) var publication_limit: int = 10
@export_range(0.0, 180.0) var coffee_bonus_seconds: float = 60.0
@export_range(0.0, 1.0) var health_drain_per_second: float = 0.10
@export_range(0.0, 10.0) var publication_health_cost: float = 1.5

@export_group("Доход")
## Scales catalogue payouts, including saved articles; rounding happens after combo.
@export_range(0.0, 2.0, 0.05) var publication_income_multiplier: float = 0.45

@export_group("Преимущества")
@export var reader_support: StatBenefit = preload("res://Data/reader_support.tres")
@export var state_approval: StatBenefit = preload("res://Data/state_approval.tres")

@export_group("Эффект усталости")
## Доля максимальной выносливости, ниже которой появляется эффект.
@export_range(0.01, 1.0, 0.01) var fatigue_threshold: float = 0.30
## 0 отключает визуальные помехи, не меняя расход выносливости.
@export_range(0.0, 1.0, 0.05) var fatigue_strength: float = 0.75

@export_group("Комбо")
@export_range(0.05, 1.0) var combo_step: float = 0.25
@export_range(1.0, 3.0) var combo_max_multiplier: float = 2.0

@export_group("Начальные значения")
@export var starting_health: float = 80.0
@export var starting_reputation: float = 65.0
@export var starting_loyalty: float = 65.0
@export var starting_money: int = 35
@export var maximum_stat: float = 100.0

@export_group("Вечер")
@export var rent: int = 45
@export var debt_limit: int = -100
@export_range(0.0, 100.0, 1.0) var sleep_health: float = 10.0
@export var meal_price: int = 25
@export var meal_health: float = 35.0
@export var snack_price: int = 12
@export var snack_health: float = 15.0
@export var coffee_price: int = 15
@export var coffee_health_cost: float = 15.0

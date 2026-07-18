# Power BI Integration Guide — Critical Minerals Market Intelligence

## 1. Connection method

**Connector:** Power BI Desktop → Get Data → Snowflake (native connector)
**Server:** `<account_identifier>.snowflakecomputing.com`
**Warehouse:** `WH_MINERALS`
**Data Connectivity mode:** DirectQuery

DirectQuery over Import here, deliberately:
- The `REPORTING` schema views are pre-aggregated where it matters (`VW_MONTHLY_PRICE_TREND`, `VW_SUPPLY_CONCENTRATION`), so query cost at the warehouse stays low.
- Commodity prices update on a scheduled cadence upstream (daily/weekly feed), and DirectQuery means the report reflects the latest load with no separate refresh schedule to manage.
- `WH_MINERALS` is sized X-SMALL with 60-second auto-suspend, so idle report views cost nothing.

**Authentication:** Service account (`svc_powerbi`) scoped to `ROLE_POWERBI_READER` — read-only on the `REPORTING` schema only. It cannot see `RAW` or `CORE`. This is the standard least-privilege pattern for any BI tool sitting on top of a warehouse.

## 2. Semantic model

Power BI connects to three objects only:

| Snowflake object | Power BI table | Purpose |
|---|---|---|
| `REPORTING.VW_MARKET_INTELLIGENCE` | `Market Intelligence` | Grain: commodity × country × supplier × month. Base table for drill-through. |
| `REPORTING.VW_MONTHLY_PRICE_TREND` | `Price Trend` | Pre-aggregated monthly average price per commodity. Feeds the trend line visual directly. |
| `REPORTING.VW_SUPPLY_CONCENTRATION` | `Supply Concentration` | Pre-aggregated production share by country per commodity per year. Feeds the concentration visual. |

Relationships: `Market Intelligence[commodity_name]` is the shared join key across all three tables (single-direction, many-to-one, to keep DirectQuery folding predictable).

## 3. Key DAX measures

```
Avg Price (Latest Month) =
VAR LatestMonth = MAX('Price Trend'[year_month])
RETURN
CALCULATE(
    AVERAGE('Price Trend'[avg_price_usd]),
    'Price Trend'[year_month] = LatestMonth
)

Price YoY % =
VAR CurrentPrice = [Avg Price (Latest Month)]
VAR PriorYearPrice =
    CALCULATE(
        AVERAGE('Price Trend'[avg_price_usd]),
        DATEADD('Price Trend'[year_month], -12, MONTH)
    )
RETURN DIVIDE(CurrentPrice - PriorYearPrice, PriorYearPrice)

Supply HHI =
-- Herfindahl-Hirschman Index: sum of squared production shares (x10,000)
-- Standard concentration-risk read for procurement / supply-security audiences.
SUMX(
    'Supply Concentration',
    'Supply Concentration'[production_share] * 'Supply Concentration'[production_share]
) * 10000
```

## 4. Report pages

1. **Overview** — four-commodity price ticker, YTD price trend lines, headline YoY movement
2. **Supply concentration** — HHI by commodity, country share breakdown, single-country dependency flags (>50% share)
3. **Supplier detail** — drill-through from any commodity/country to individual supplier volumes

## 5. Refresh & governance notes for the client conversation

- DirectQuery removes the "why is the number different in Power BI vs Snowflake" question entirely, at the cost of report responsiveness depending on warehouse size — worth surfacing explicitly as a trade-off, not a default.
- Row-level security, if the client needs region-locked access (e.g., a country desk only seeing its own geography), gets enforced at the Snowflake role level, not in Power BI — keeps the security boundary in one place.

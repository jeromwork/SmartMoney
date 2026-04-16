#property strict

enum ENUM_SM_MODE
{
    LiveManualConfirm = 0,
    AutoTest = 1
};

enum ENUM_SM_COMPOSITION
{
    SM_COMPOSITION_AND = 0,
    SM_COMPOSITION_OR = 1,
    SM_COMPOSITION_SCORE_THRESHOLD = 2
};

enum ENUM_SM_DIRECTION
{
    SM_DIRECTION_NONE = 0,
    SM_DIRECTION_BUY = 1,
    SM_DIRECTION_SELL = -1
};

struct SM_SignalFeature
{
    string feature_id;
    double value;
    datetime timestamp;
    double quality;
};

struct SM_SignalContext
{
    string symbol;
    ENUM_TIMEFRAMES timeframe;
    int direction;
    double score;
    string reasons;
    double invalidation;
    double sl;
    double tp;
    bool valid;
};

class IIndicatorProvider
{
public:
    virtual bool Init(const string symbol, const ENUM_TIMEFRAMES timeframe) = 0;
    virtual bool Refresh() = 0;
    virtual double GetValue(const int buffer_id, const int shift) = 0;
    virtual string GetState() = 0;
    virtual string Name() = 0;
    virtual void Deinit() = 0;
};

class ISignalProvider
{
public:
    virtual bool BuildSignal(SM_SignalContext &context) = 0;
    virtual string Name() = 0;
    virtual void Deinit() = 0;
};

class IFilterProvider
{
public:
    virtual bool Allow(const SM_SignalContext &context, string &reason) = 0;
    virtual string Name() = 0;
};

class IExecutionPolicy
{
public:
    virtual bool BuildOrder(const SM_SignalContext &context, double &volume, double &entry_price, double &sl, double &tp) = 0;
    virtual bool CanSend(const SM_SignalContext &context, string &reason) = 0;
    virtual bool Send(const SM_SignalContext &context, const double volume, const double entry_price, const double sl, const double tp, string &result) = 0;
    virtual string Name() = 0;
};

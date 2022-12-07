def to_bool(a):
    ''' return a bool for the arg '''
    if a is None or isinstance(a, bool):
        return a
    if isinstance(a, str):
        a = a.lower()
    if a in ('yes', 'on', '1', 'true', 1):
        return True
    return False
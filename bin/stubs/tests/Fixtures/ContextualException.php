<?php

declare(strict_types=1);

namespace Dirthara\__NAMESPACE__\Tests\Fixtures;

use RuntimeException;
use Dirthara\__NAMESPACE__\Exception\HasExceptionContext;
use Dirthara\__NAMESPACE__\Exception\__NAMESPACE__Exception;

final class ContextualException extends RuntimeException implements __NAMESPACE__Exception
{
    use HasExceptionContext;

    public static function describe(string $value): string
    {
        return self::printable($value);
    }
}

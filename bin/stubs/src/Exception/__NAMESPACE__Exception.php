<?php

declare(strict_types=1);

namespace Dirthara\__NAMESPACE__\Exception;

use Throwable;

interface __NAMESPACE__Exception extends Throwable
{
    /**
     * @var array<string, mixed>
     */
    public array $context { get; }

    /**
     * @param array<string, mixed> $context
     */
    public function addContext(array $context): static;
}

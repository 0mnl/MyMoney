package mymoney.di

import mymoney.config.AppConfig
import mymoney.config.DbConfig
import mymoney.config.JwtConfig
import mymoney.data.db.DatabaseFactory
import mymoney.data.repository.AccountRepositoryImpl
import mymoney.data.repository.BudgetRepositoryImpl
import mymoney.data.repository.CategoryRepositoryImpl
import mymoney.data.repository.FamilyInviteRepositoryImpl
import mymoney.data.repository.FamilyMemberRepositoryImpl
import mymoney.data.repository.FamilyRepositoryImpl
import mymoney.data.repository.DebtRepositoryImpl
import mymoney.data.repository.SubscriptionRepositoryImpl
import mymoney.data.repository.SyncRepositoryImpl
import mymoney.data.repository.GoalRepositoryImpl
import mymoney.data.repository.RefreshTokenRepositoryImpl
import mymoney.data.repository.TransactionHistoryRepositoryImpl
import mymoney.data.repository.TransactionRepositoryImpl
import mymoney.data.repository.EmailVerificationRepositoryImpl
import mymoney.data.repository.UserRepositoryImpl
import mymoney.data.notification.LoggingVerificationCodeSender
import mymoney.data.security.Argon2PasswordHasher
import mymoney.data.security.JwtTokenService
import mymoney.data.security.Sha256VerificationCodeService
import mymoney.domain.repository.AccountRepository
import mymoney.domain.repository.BudgetRepository
import mymoney.domain.repository.CategoryRepository
import mymoney.domain.repository.EmailVerificationRepository
import mymoney.domain.repository.FamilyInviteRepository
import mymoney.domain.repository.FamilyMemberRepository
import mymoney.domain.repository.FamilyRepository
import mymoney.domain.repository.GoalRepository
import mymoney.domain.repository.RefreshTokenRepository
import mymoney.domain.repository.DebtRepository
import mymoney.domain.repository.SubscriptionRepository
import mymoney.domain.repository.SyncRepository
import mymoney.domain.repository.TransactionHistoryRepository
import mymoney.domain.repository.TransactionRepository
import mymoney.domain.repository.UserRepository
import mymoney.domain.security.PasswordHasher
import mymoney.domain.security.TokenService
import mymoney.domain.security.VerificationCodeService
import mymoney.domain.usecase.account.ArchiveAccountUseCase
import mymoney.domain.usecase.account.CreateAccountUseCase
import mymoney.domain.usecase.account.DeleteAccountUseCase
import mymoney.domain.usecase.account.GetAccountUseCase
import mymoney.domain.usecase.account.ListAccountsUseCase
import mymoney.domain.usecase.account.UpdateAccountUseCase
import mymoney.domain.usecase.auth.LoginUseCase
import mymoney.domain.usecase.auth.LogoutAllUseCase
import mymoney.domain.usecase.auth.RefreshTokenUseCase
import mymoney.domain.usecase.auth.RegisterUserUseCase
import mymoney.domain.usecase.auth.ResendVerificationCodeUseCase
import mymoney.domain.usecase.auth.VerificationCodeIssuer
import mymoney.domain.usecase.auth.VerificationCodeSender
import mymoney.domain.usecase.auth.VerifyEmailUseCase
import mymoney.domain.usecase.category.ArchiveCategoryUseCase
import mymoney.domain.usecase.category.CreateCategoryUseCase
import mymoney.domain.usecase.category.DeleteCategoryUseCase
import mymoney.domain.usecase.category.GetCategoryUseCase
import mymoney.domain.usecase.category.ListCategoriesUseCase
import mymoney.domain.usecase.category.SeedSystemCategoriesUseCase
import mymoney.domain.usecase.category.UpdateCategoryUseCase
import mymoney.domain.usecase.family.AcceptFamilyInviteUseCase
import mymoney.domain.usecase.family.InviteFamilyMemberUseCase
import mymoney.domain.usecase.family.InviteTokenGenerator
import mymoney.domain.usecase.family.ListFamilyMembersUseCase
import mymoney.domain.usecase.debt.CreateDebtUseCase
import mymoney.domain.usecase.debt.DeleteDebtUseCase
import mymoney.domain.usecase.debt.GetDebtUseCase
import mymoney.domain.usecase.debt.ListDebtsUseCase
import mymoney.domain.usecase.debt.UpdateDebtUseCase
import mymoney.domain.usecase.subscription.AdvanceSubscriptionUseCase
import mymoney.domain.usecase.subscription.CreateSubscriptionUseCase
import mymoney.domain.usecase.subscription.DeleteSubscriptionUseCase
import mymoney.domain.usecase.subscription.GetSubscriptionUseCase
import mymoney.domain.usecase.subscription.ListSubscriptionsUseCase
import mymoney.domain.usecase.subscription.UpdateSubscriptionUseCase
import mymoney.domain.usecase.sync.PullChangesUseCase
import mymoney.domain.usecase.sync.PushChangesUseCase
import mymoney.domain.usecase.transaction.CreateTransactionUseCase
import mymoney.domain.usecase.transaction.DeleteTransactionUseCase
import mymoney.domain.usecase.transaction.GetTransactionHistoryUseCase
import mymoney.domain.usecase.transaction.GetTransactionUseCase
import mymoney.domain.usecase.transaction.ListTransactionsUseCase
import mymoney.domain.usecase.transaction.UpdateTransactionUseCase
import mymoney.domain.usecase.budget.CreateBudgetUseCase
import mymoney.domain.usecase.budget.DeleteBudgetUseCase
import mymoney.domain.usecase.budget.GetBudgetProgressUseCase
import mymoney.domain.usecase.budget.GetBudgetUseCase
import mymoney.domain.usecase.budget.ListBudgetsUseCase
import mymoney.domain.usecase.budget.UpdateBudgetUseCase
import mymoney.domain.usecase.goal.ContributeGoalUseCase
import mymoney.domain.usecase.goal.CreateGoalUseCase
import mymoney.domain.usecase.goal.DeleteGoalUseCase
import mymoney.domain.usecase.goal.GetGoalUseCase
import mymoney.domain.usecase.goal.ListGoalsUseCase
import mymoney.domain.usecase.goal.UpdateGoalUseCase
import org.koin.dsl.module

fun appModule(
    config: AppConfig,
    databaseFactory: DatabaseFactory,
    verificationCodeSender: VerificationCodeSender? = null,
) = module {
    // Config
    single { config }
    single<DbConfig> { config.db }
    single<JwtConfig> { config.jwt }

    // Infra
    single { databaseFactory }
    single { databaseFactory.database }

    // Repositories
    single<FamilyRepository> { FamilyRepositoryImpl(get()) }
    single<FamilyMemberRepository> { FamilyMemberRepositoryImpl(get()) }
    single<FamilyInviteRepository> { FamilyInviteRepositoryImpl(get()) }
    single<UserRepository> { UserRepositoryImpl(get()) }
    single<EmailVerificationRepository> { EmailVerificationRepositoryImpl(get()) }
    single<RefreshTokenRepository> { RefreshTokenRepositoryImpl(get()) }
    single<AccountRepository> { AccountRepositoryImpl(get()) }
    single<CategoryRepository> { CategoryRepositoryImpl(get()) }
    single<TransactionRepository> { TransactionRepositoryImpl(get()) }
    single<TransactionHistoryRepository> { TransactionHistoryRepositoryImpl(get()) }
    single<BudgetRepository> { BudgetRepositoryImpl(get()) }
    single<GoalRepository> { GoalRepositoryImpl(get()) }
    single<SyncRepository> { SyncRepositoryImpl(get()) }
    single<DebtRepository> { DebtRepositoryImpl(get()) }
    single<SubscriptionRepository> { SubscriptionRepositoryImpl(get()) }

    // Security
    single<PasswordHasher> { Argon2PasswordHasher() }
    single<TokenService> { JwtTokenService(get()) }
    single<VerificationCodeService> { Sha256VerificationCodeService() }

    // Confirmation-code delivery. Development logs the code instead of sending
    // mail; wire an SMTP implementation here before going to production.
    single<VerificationCodeSender> { verificationCodeSender ?: LoggingVerificationCodeSender() }

    // Category use cases (declared before auth so RegisterUserUseCase can inject seed)
    single { SeedSystemCategoriesUseCase(get()) }
    single { CreateCategoryUseCase(get()) }
    single { ListCategoriesUseCase(get()) }
    single { GetCategoryUseCase(get()) }
    single { UpdateCategoryUseCase(get()) }
    single { ArchiveCategoryUseCase(get()) }
    single { DeleteCategoryUseCase(get()) }

    // Auth use cases
    single { VerificationCodeIssuer(get(), get(), get()) }
    single { RegisterUserUseCase(get(), get(), get(), get(), get(), get()) }
    single { VerifyEmailUseCase(get(), get(), get(), get(), get(), get()) }
    single { ResendVerificationCodeUseCase(get(), get()) }
    single { LoginUseCase(get(), get(), get(), get(), get()) }
    single { RefreshTokenUseCase(get(), get(), get()) }
    single { LogoutAllUseCase(get()) }

    // Account use cases
    single { CreateAccountUseCase(get()) }
    single { ListAccountsUseCase(get()) }
    single { GetAccountUseCase(get()) }
    single { UpdateAccountUseCase(get()) }
    single { ArchiveAccountUseCase(get()) }
    single { DeleteAccountUseCase(get()) }

    // Transaction use cases
    single { CreateTransactionUseCase(get(), get(), get()) }
    single { ListTransactionsUseCase(get()) }
    single { GetTransactionUseCase(get()) }
    single { UpdateTransactionUseCase(get(), get(), get()) }
    single { DeleteTransactionUseCase(get()) }
    single { GetTransactionHistoryUseCase(get(), get()) }

    // Budget use cases
    single { CreateBudgetUseCase(get(), get()) }
    single { ListBudgetsUseCase(get()) }
    single { GetBudgetUseCase(get()) }
    single { UpdateBudgetUseCase(get()) }
    single { DeleteBudgetUseCase(get()) }
    single { GetBudgetProgressUseCase(get()) }

    // Family use cases
    single { InviteTokenGenerator() }
    single { InviteFamilyMemberUseCase(get(), get(), get(), get()) }
    single { AcceptFamilyInviteUseCase(get(), get(), get()) }
    single { ListFamilyMembersUseCase(get()) }

    // Sync use cases
    single { PullChangesUseCase(get()) }
    single { PushChangesUseCase(get()) }

    // Debt use cases
    single { CreateDebtUseCase(get()) }
    single { ListDebtsUseCase(get()) }
    single { GetDebtUseCase(get()) }
    single { UpdateDebtUseCase(get()) }
    single { DeleteDebtUseCase(get()) }

    // Subscription use cases
    single { CreateSubscriptionUseCase(get()) }
    single { ListSubscriptionsUseCase(get()) }
    single { GetSubscriptionUseCase(get()) }
    single { UpdateSubscriptionUseCase(get()) }
    single { DeleteSubscriptionUseCase(get()) }
    single { AdvanceSubscriptionUseCase(get()) }

    // Goal use cases
    single { CreateGoalUseCase(get()) }
    single { ListGoalsUseCase(get()) }
    single { GetGoalUseCase(get()) }
    single { UpdateGoalUseCase(get()) }
    single { DeleteGoalUseCase(get()) }
    single { ContributeGoalUseCase(get()) }
}

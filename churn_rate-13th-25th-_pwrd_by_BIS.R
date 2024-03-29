x <- c("tidyverse", "ggplot2","lubridate", "DescTools")
lapply(x,library,character.only=TRUE)
task1 <- read.delim("유지율 예측용 기초자료_1.txt")
task2 <- read.delim("유지율 예측용 기초자료_2.txt",fileEncoding="euc-kr")
task3 <- read.delim("유지율 예측용 기초자료_3.txt",fileEncoding="euc-kr")
task4 <- read.delim("유지율 예측용 기초자료_4.txt",fileEncoding="euc-kr")
task <- rbind(task1,task2,task3,task4)
colnames(task)

#데이터제한(계약일자>=20180101, 13회차경과분|25회차경과분) 
task <- subset(task,nchar(계약자주민번호)!=6 & 계약일자>=20180101)
task$계약일자 = as.character(task$계약일자) %>% as.Date(format="%Y%m%d")
task <- subset(task,계약일자 <= max(task$계약일자) %m-% months(13))

# 날짜타입적용(결측치 처리)
task$최종입금일자 = as.character(task$최종입금일자) %>% as.Date(format="%Y%m%d")
task$소멸일자 = as.character(task$소멸일자) %>% as.Date(format="%Y%m%d")
task$소멸일자[is.na(task$소멸일자)] <- '9999-12-31'
task$해촉일 = as.character(task$해촉일) %>% as.Date(format="%Y%m%d")
task$해촉일[is.na(task$해촉일)] <- '9999-12-31'


# 성별
task$계약자성별 <- ifelse(nchar(task$계약자주민번호)==10, "N" ,ifelse(as.numeric(substr(task$계약자주민번호,7,7))%%2==0, "F", "M")) # M:남성/F:여성/N:법인


# 해촉영향(해촉<=소멸)
task$해촉영향 <- with(task,ifelse(해촉일<=소멸일자, 1, 0))




# 13회차 유지
task$유지over13 <- with(task, ifelse(납입주기=="월납" & 최종납입회차>=13, 1,
                                   ifelse(납입주기 =="3개월납" & 최종납입회차 >=5, 1,
                                          ifelse(납입주기 == "6개월납" & 최종납입회차 >=3, 1,
                                                 ifelse(납입주기 == "연납" & 최종납입회차 >=2, 1,
                                                        ifelse(납입주기 == "일시납" & 소멸일자 >= (계약일자 %m+% months(13)), 1, 0))))) )

# 25회차 유지
task$유지over25 <- with(task, ifelse(납입주기=="월납" & 최종납입회차>=25, 1,
                                   ifelse(납입주기 =="3개월납" & 최종납입회차 >=9, 1,
                                          ifelse(납입주기 == "6개월납" & 최종납입회차 >=5, 1,
                                                 ifelse(납입주기 == "연납" & 최종납입회차 >=3, 1,
                                                        ifelse(납입주기 == "일시납" & 소멸일자 >= (계약일자 %m+% months(25)), 1, 0))))) )

###############################################################################################################################################################

# 납입기간
task %>% with(Desc(년기준))
# Through trials and errors, I knew that it's required to transform yet again as below
# scorecard::woebin(input, y="churn13", x=c("period"),positive=1, method="tree",count_distr_limit = 0.05,bin_num_limit = 6, save_breaks_list = "input_bin_count")
task <- task %>% mutate(년기준_new = ifelse(년기준 < 1, 1,
                                              ifelse(년기준 < 10, 2,
                                                     ifelse(년기준 <  16, 3, 4))))


# 약관대출잔액
task$약관대출잔액[is.na(task$약관대출잔액)] <- 0

task %>% with(Desc(약관대출잔액))
# Through trials and errors, I knew that it's required to transform yet again as below
# scorecard::woebin(input, y="churn13", x=c("loan_residual"),positive=1, method="tree",count_distr_limit = 0.05,bin_num_limit = 6, save_breaks_list = "input_bin_count")
task$약관대출잔액_new <- ifelse(task$약관대출잔액>0,1,0)


# 계약자나이
year1 <- substr(task$계약자주민번호, 1, 2) 
month <- substr(task$계약자주민번호, 3, 4) 
day <- substr(task$계약자주민번호, 5, 6)
year2 <- ifelse(as.numeric(year1) >= 0 & as.numeric(year1)<= 23, paste0("20", year1), paste0("19", year1))
age <- year(task$계약일자) - as.numeric(year2) + ifelse(month(task$계약일자) < as.numeric(month) |
                                                      (month(task$계약일자) == as.numeric(month) & day(task$계약일자) < as.numeric(day)), -1, 0)
mean_age <- round(mean(age,na.rm=TRUE),0)
task$계약자나이 <- ifelse(nchar(task$계약자주민번호)==10,mean_age,age)

task %>% with(Desc(계약자나이))
# Through trials and errors, I knew that it's required to transform yet again as below
# scorecard::woebin(input, y="churn13", x=c("ctrt_age"),positive=1, method="tree",count_distr_limit = 0.05,bin_num_limit = 6, save_breaks_list = "input_bin_count")
task <- task %>% mutate(계약자나이_new = ifelse(계약자나이 < 32, 1,
                                           ifelse(계약자나이 < 52, 2,
                                                  ifelse(계약자나이 <  56, 3, 4))))


# 변환보험료(월납/1, 3개월납/3, 6개월납/6, 연납/12, 일시납/50)
pay_cycle <- c("월납","3개월납","6개월납","연납","일시납")
pay_cycle_as_num <- c(1,3,6,12,50)
(pay_cycle_table1 <- data.frame(pay_cycle,pay_cycle_as_num))
temp <- as.data.frame(task$납입주기)
colnames(temp) <- "pay_cycle"
pay_cycle_table2 <- left_join(temp,pay_cycle_table1);pay_cycle_table2
task$변환보험료 <- unlist(task$최종합계보험료/pay_cycle_table2[2])

task %>% with(Desc(변환보험료))
# Through trials and errors, I knew that it's required to transform yet again as below
# scorecard::woebin(input, y="churn13", x=c("premium_trans"),positive=1, method="tree",count_distr_limit = 0.05,bin_num_limit = 6, save_breaks_list = "input_bin_count")
task <- task %>% mutate(변환보험료_new = ifelse(변환보험료 < 120000, 1,
                                           ifelse(변환보험료 < 200000, 2,
                                                  ifelse(변환보험료 <  220000, 3,
                                                         ifelse(변환보험료 < 460000, 4,
                                                                ifelse(변환보험료 < 600000, 5, 6))))))


# 보험금액 감액(결측치 처리)
task$합계보험료[is.na(task$합계보험료)] <- 0
task$감액 <- with(task, ifelse(합계보험료>최종합계보험료, unlist((합계보험료-최종합계보험료)/pay_cycle_table2[2]), 0))

task %>% with(Desc(감액))
# Through trials and errors, I knew that it's required to transform yet again as below
# scorecard::woebin(input, y="churn13", x=c("resize"),positive=1, method="tree",count_distr_limit = 0.05,bin_num_limit = 6, save_breaks_list = "input_bin_count")
task$감액_new <- with(task, ifelse(합계보험료>최종합계보험료, 1, 0))

#####################################################################################################################

str(task)

# feature list: 모집채널, 납입주기, 년기준, 생명보험협회상품종류, 약관대출잔액, 계약자성별, 계약자나이, 해촉영향, 변환보험료, 감액, 유지over13, 유지over25

input <- subset(task,select=c("모집채널",
                              "납입주기",
                              "년기준_new",
                              "생명보험협회상품종류",
                              "약관대출잔액_new",
                              "계약자성별",
                              "계약자나이_new",
                              "해촉영향",
                              "변환보험료_new",
                              "감액_new",
                              "유지over13",
                              "유지over25"))


input <- input %>% rename(channel="모집채널",
                          cycle="납입주기",
                          period="년기준_new",
                          sort="생명보험협회상품종류",
                          loan_residual="약관대출잔액_new",
                          ctrt_gender="계약자성별",
                          ctrt_age="계약자나이_new",
                          if_resign="해촉영향",
                          premium_trans="변환보험료_new",
                          resize="감액_new",
                          churn13="유지over13",
                          churn25="유지over25")


# 범주변수를 factor로 변환
input$channel <- factor(input$channel)
input$cycle <- factor(input$cycle)
input$period <- factor(input$period)
input$sort <- factor(input$sort)
input$loan_residual <- factor(input$loan_residual)
input$ctrt_gender <- factor(input$ctrt_gender)
input$ctrt_age <- factor(input$ctrt_age)
input$if_resign <- factor(input$if_resign)
input$premium_trans <- factor(input$premium_trans)
input$resize <- factor(input$resize)
input$churn13 <- factor(input$churn13)
input$churn25 <- factor(input$churn25)


#범주변수 EDA
summary(input$channel)
# table(input$channel)
proportions(table(input$channel))
input %>% ggplot(aes(x=channel, fill=channel)) + 
  geom_bar() + 
  labs(x = "모집채널", y="빈도", fill ="모집채널") 
input %>% ggplot(aes(x=channel, fill=channel)) + 
  geom_bar(aes(y = (..count..)/sum(..count..))) +
  labs(x = "모집채널", y="percent", fill ="모집채널") 

summary(input$cycle)
# table(input$cycle)
proportions(table(input$cycle))
input %>% ggplot(aes(x=cycle, fill=cycle)) + 
  geom_bar() + 
  labs(x = "납입주기", y="빈도", fill ="납입주기") 
input %>% ggplot(aes(x=cycle, fill=cycle)) + 
  geom_bar(aes(y = (..count..)/sum(..count..))) +
  labs(x = "납입주기", y="percent", fill ="납입주기") 

summary(input$period)
# table(input$period)
proportions(table(input$period))
input %>% ggplot(aes(x=period, fill=period)) + 
  geom_bar() + 
  labs(x = "납입기간", y="빈도", fill ="납입기간") 
input %>% ggplot(aes(x=period, fill=period)) + 
  geom_bar(aes(y = (..count..)/sum(..count..))) +
  labs(x = "납입기간", y="percent", fill ="납입기간") 

summary(input$sort)
# table(input$sort)
proportions(table(input$sort))
input %>% ggplot(aes(x=sort, fill=sort)) + 
  geom_bar() + 
  labs(x = "생명보험협회상품종류", y="빈도", fill ="생명보험협회상품종류") 
input %>% ggplot(aes(x=sort, fill=sort)) + 
  geom_bar(aes(y = (..count..)/sum(..count..))) +
  labs(x = "생명보험협회상품종류", y="percent", fill ="생명보험협회상품종류") 

summary(input$loan_residual)
# table(input$loan_residual)
proportions(table(input$loan_residual))
input %>% ggplot(aes(x=loan_residual, fill=loan_residual)) + 
  geom_bar() + 
  labs(x = "약관대출잔액", y="빈도", fill ="약관대출잔액") 
input %>% ggplot(aes(x=loan_residual, fill=loan_residual)) + 
  geom_bar(aes(y = (..count..)/sum(..count..))) +
  labs(x = "약관대출잔액", y="percent", fill ="약관대출잔액") 

summary(input$ctrt_gender)
# table(input$ctrt_gender)
proportions(table(input$ctrt_gender))
input %>% ggplot(aes(x=ctrt_gender, fill=ctrt_gender)) + 
  geom_bar() + 
  labs(x = "계약자성별", y="빈도", fill ="계약자성별") 
input %>% ggplot(aes(x=ctrt_gender, fill=ctrt_gender)) + 
  geom_bar(aes(y = (..count..)/sum(..count..))) +
  labs(x = "계약자성별", y="percent", fill ="계약자성별") 

summary(input$ctrt_age)
# table(input$ctrt_age)
proportions(table(input$ctrt_age))
input %>% ggplot(aes(x=ctrt_age, fill=ctrt_age)) + 
  geom_bar() + 
  labs(x = "계약자나이", y="빈도", fill ="계약자나이") 
input %>% ggplot(aes(x=ctrt_age, fill=ctrt_age)) + 
  geom_bar(aes(y = (..count..)/sum(..count..))) +
  labs(x = "계약자나이", y="percent", fill ="계약자나이") 

summary(input$if_resign)
# table(input$if_resign)
proportions(table(input$if_resign))
input %>% ggplot(aes(x=if_resign, fill=if_resign)) + 
  geom_bar() + 
  labs(x = "해촉영향", y="빈도", fill ="해촉영향") 
input %>% ggplot(aes(x=if_resign, fill=if_resign)) + 
  geom_bar(aes(y = (..count..)/sum(..count..))) +
  labs(x = "해촉영향", y="percent", fill ="해촉영향") 

summary(input$premium_trans)
# table(input$if_resign)
proportions(table(input$premium_trans))
input %>% ggplot(aes(x=premium_trans, fill=premium_trans)) + 
  geom_bar() + 
  labs(x = "변환보험료", y="빈도", fill ="변환보험료") 
input %>% ggplot(aes(x=premium_trans, fill=premium_trans)) + 
  geom_bar(aes(y = (..count..)/sum(..count..))) +
  labs(x = "변환보험료", y="percent", fill ="변환보험료") 

summary(input$resize)
# table(input$resize)
proportions(table(input$resize))
input %>% ggplot(aes(x=resize, fill=resize)) + 
  geom_bar() + 
  labs(x = "보험금액 감액", y="빈도", fill ="보험금액 감액") 
input %>% ggplot(aes(x=resize, fill=resize)) + 
  geom_bar(aes(y = (..count..)/sum(..count..))) +
  labs(x = "보험금액 감액", y="percent", fill ="보험금액 감액") 

summary(input$churn13)
# table(input$churn13)
proportions(table(input$churn13))
input %>% ggplot(aes(x=churn13, fill=churn13)) + 
  geom_bar() + 
  labs(x = "13회차유지", y="빈도", fill ="13회차유지") 
input %>% ggplot(aes(x=churn13, fill=churn13)) + 
  geom_bar(aes(y = (..count..)/sum(..count..))) +
  labs(x = "13회차유지", y="percent", fill ="13회차유지") 

summary(input$churn25)
# table(input$churn25)
proportions(table(input$churn25))

input %>% ggplot(aes(x=churn25, fill=churn25)) + 
  geom_bar() + 
  labs(x = "25회차유지", y="빈도", fill ="25회차유지") 
input %>% ggplot(aes(x=churn25, fill=churn25)) + 
  geom_bar(aes(y = (..count..)/sum(..count..))) +
  labs(x = "25회차유지", y="percent", fill ="25회차유지") 

# information value 산출
library(remotes)
install_github("tomasgreif/woe")
library(woe)

iv.all <- iv.mult(df=subset(input,select=-c(churn25)), y="churn13", summary=TRUE)
iv.plot.summary(iv.all)


# 데이터 샘플링
set.seed(111)
index <- sample(x=c(TRUE,FALSE), size=NROW(input), replace=TRUE, prob=c(0.8,0.2))

train <- input[index,]
test <- input[!index,]
str(train)

# 로지스틱회귀분석
model_logistic <- glm(churn13 ~ channel + cycle + period + sort + loan_residual + ctrt_gender + ctrt_age + if_resign + premium_trans + resize,
                      data=train, family=binomial(link='logit'))
step(model_logistic, direction="both")
summary(model_logistic)
1-pchisq(122036,df=122450) # p-value가 0.7984715로 로지스틱회귀모형이 통계적으로 유의하다고 해석


# install.packages("ROCR")
library(ROCR)

train_prediction <- predict(model_logistic, newdata = train, type='response')
pred_train <- prediction(predictions = as.numeric(train_prediction),labels=as.numeric(train$churn13))
auc_train <- performance(prediction.obj = pred_train,measure='auc')
auc_value_train=unlist(slot(auc_train,'y.values'))
paste(c('train AUC='),round(auc_value_train,6),sep="")
perf_train <- performance(pred_train,measure='tpr', x.measure='fpr')
plot(perf_train)

library(caret)
confusionMatrix(factor(ifelse(train_prediction>.5, 1, 0)), factor(as.numeric(train$churn13)-1))
 
test_prediction <- predict(model_logistic, newdata = test, type='response')
pred_test <- prediction(predictions = test_prediction,labels=test$churn13)
auc_test <- performance(prediction.obj = pred_test,measure='auc')
auc_value_test=unlist(slot(auc_test,'y.values'))
paste(c('AUC='),round(auc_value_test,6),sep="")
perf_test <- performance(pred_test,measure='tpr', x.measure='fpr')
plot(perf_test)

confusionMatrix(factor(ifelse(test_prediction>.5, 1, 0)), factor(as.numeric(test$churn13)-1))

# 의사결정나무
library(rpart)
CARTmodel <- rpart(churn13 ~ channel + cycle + period + sort + loan_residual + ctrt_gender + ctrt_age + if_resign + premium_trans + resize,
                  data=train, control=rpart.control(minsplit=5))
# summary(CARTmodel)
CARTmodel
train_prediction <- predict(CARTmodel, newdata = train, type='prob')
pred_train <- prediction(predictions = train_prediction[,2],labels=train$churn13)
auc_train <- performance(prediction.obj = pred_train,measure='auc')
auc_value_train=unlist(slot(auc_train,'y.values'))
paste(c('train AUC='),round(auc_value_train,6),sep="")
perf_train <- performance(pred_train,measure='tpr', x.measure='fpr')
plot(perf_train)

confusionMatrix(factor(ifelse(train_prediction[,2]>.5, 1, 0)), factor(as.numeric(train$churn13)-1))


test_prediction <- predict(CARTmodel, newdata = test, type='prob')
pred_test <- prediction(predictions = test_prediction[,2],labels=test$churn13)
auc_test <- performance(prediction.obj = pred_test,measure='auc')
auc_value_test=unlist(slot(auc_test,'y.values'))
paste(c('AUC='),round(auc_value_test,6),sep="")
perf_test <- performance(pred_test,measure='tpr', x.measure='fpr')
plot(perf_test)

confusionMatrix(factor(ifelse(test_prediction[,2]>.5, 1, 0)), factor(as.numeric(test$churn13)-1))

library(rpart.plot)
rpart.plot::prp(CARTmodel, type=4, extra=2,digits=3)


# 앙상블-Bagging
library(adabag)
bagging_model <- bagging(churn13 ~ channel + cycle + period + sort + loan_residual + ctrt_gender + ctrt_age + if_resign + premium_trans + resize,
                         data=train, mfinal=100)
test_prediction <- predict(bagging_model, newdata = test)
confusionMatrix(factor(test_prediction$class), factor(as.numeric(test$churn13)-1))


# 앙상블-Boosting
library(adabag)
boosting_model <- boosting(churn13 ~ channel + cycle + period + sort + loan_residual + ctrt_gender + ctrt_age + if_resign + premium_trans + resize,
                         data=train, boos=TRUE, mfinal=30)
test_prediction <- predict(boosting_model, newdata = test)
confusionMatrix(factor(test_prediction$class), factor(as.numeric(test$churn13)-1))


# 앙상블-랜덤포레스트
library(randomForest)
forest_model <- randomForest(churn13 ~ channel + cycle + period + sort + loan_residual + ctrt_gender + ctrt_age + if_resign + premium_trans + resize,
                             data=train, ntree=100, mtry=5)
test_prediction <- predict(forest_model, newdata = test, type='prob')
confusionMatrix(factor(ifelse(test_prediction[,2]>.5, 1, 0)), factor(as.numeric(test$churn13)-1))
# importance(forest_model)
# varImpPlot(forest_model,main="변수중요도평가")


# 인공신경망
library(nnet)
nn_model <- nnet(churn13 ~ channel + cycle + period + sort + loan_residual + ctrt_gender + ctrt_age + if_resign + premium_trans + resize,
                 data=train, size=5, rang=0.5, decay=5e-4, maxit=1000)
test_prediction <- predict(nn_model, newdata = test, type='raw')
confusionMatrix(factor(ifelse(test_prediction>.5, 1, 0)), factor(as.numeric(test$churn13)-1))
